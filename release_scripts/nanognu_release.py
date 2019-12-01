import hashlib
import os
import datetime
import sys
import re
import fnmatch
import shutil
import subprocess
import tarfile
import grp

# check python version
if (sys.version_info <= (3, 0)):
  print ("ERROR: script needs at least python3")
  sys.exit(1)

# Set the version of the tools to release
if len(sys.argv) < 2:
  print("ERROR: Please specify version number")
  sys.exit(1)

version = sys.argv[1]
if len(sys.argv) == 3:
  relnotes = sys.argv[2]
else:
  relnotes = None
today = datetime.date.today();

def md5sum(filename):
  f = open(filename, mode='rb')
  d = hashlib.md5()
  d.update(f.read())
  return d.hexdigest()

def sha256sum(filename):
  f = open(filename, mode='rb')
  d = hashlib.sha256()
  d.update(f.read())
  return d.hexdigest()

def grok_release_content(ctype,ctext):
  out=""
  for ct in ctext:
    if ct.startswith(ctype):
      for l in ct.splitlines()[1:]:
        if not l.strip():
          continue
        elif l.startswith("<li>") or l.startswith("<ul>"):
          out += "\t\t" + l + "\n"
        elif l.startswith("*"):
          out += "\t\t" + l.lstrip("*") + "\n"
        else:
          out += "\t\t<li>" + l + "</li>\n"
  if not out:
    out += "\t\t<li>None</li>\n"
  return "\t\t<ul>\n" + out + "\t\t</ul>\n"

host_to_name = { "i686-pc-linux-gnu" : "CentOS-6.x86",
		 "x86_64-pc-linux-gnu" : "CentOS-6.x86_64",
		 "i686-w64-mingw32" : "Windows.x86",
		 "x86_64-w64-mingw32" : "Windows.x86_64" }

host_to_var = { "i686-pc-linux-gnu" : "L32",
		"x86_64-pc-linux-gnu" : "L64",
		"i686-w64-mingw32" : "W32",
		"x86_64-w64-mingw32" : "W64" }

target_to_name = { "nanomips-elf" : "Bare.Metal",
		   "nanomips-linux-musl" : "Linux" }

target_to_var = { "nanomips-elf" : "NE",
		  "nanomips-linux-musl" : "NLM" }

scriptpath=os.path.dirname(os.path.realpath(__file__))

if True:
  f = open("%s/nanotemplate/downloads.tmpl" % scriptpath, mode='r')
  template = f.read()
  f.close()

  for target in ["nanomips-elf", "nanomips-linux-musl"]:
    for host in ["i686-pc-linux-gnu", "i686-w64-mingw32", "x86_64-pc-linux-gnu", "x86_64-w64-mingw32"]:
      if not os.path.exists ("%s_%s.tgz" % (target, host)):
        print ("ERROR: Toolkit tarball file missing %s_%s.tgz" % (target, host))
        sys.exit(1)
      filename = "Codescape.GNU.Tools.Package.%s.for.nanoMIPS.%s.%s.tar.gz" % (version, target_to_name[target], host_to_name[host])
      if os.path.exists (filename):
        print ("ERROR: Toolkit tarball destination already exists %s" % filename)
        sys.exit(1)

  components = ["binutils", "gdb", "gold", "newlib", "gcc", "smallclib", "qemu", "musl", "packages", "python"]
  for component in components:
    filenameraw = "%s-%s.src.tar.gz" % (component, version)
    filename = "src/%s" % (filenameraw)
    if not os.path.exists (filename):
      print ("ERROR: source package for %s (%s) missing" % (component, filename))
      sys.exit(1)

  for target in ["nanomips-elf", "nanomips-linux-musl"]:
    for host in ["i686-pc-linux-gnu", "i686-w64-mingw32", "x86_64-pc-linux-gnu", "x86_64-w64-mingw32"]:
      filename = "Codescape.GNU.Tools.Package.%s.for.nanoMIPS.%s.%s.tar.gz" % (version, target_to_name[target], host_to_name[host])
      os.rename("%s_%s.tgz" % (target, host), filename)
      varsuffix = "_%s_%s" % (host_to_var[host], target_to_var[target])
      # Size in megabytes
      thesize = os.path.getsize(filename) >> 20
      # md5sum
      themd5 = md5sum(filename)
      # sha256sum
      thesha256 = sha256sum(filename)
      print("%s %s %s %s %s" %(filename,varsuffix,thesize,themd5,thesha256))

      template = template.replace("${NAME%s}" % varsuffix, filename)
      template = template.replace("${SIZE%s}" % varsuffix, str(thesize))
      template = template.replace("${MD5%s}" % varsuffix, themd5)
      template = template.replace("${SHA256%s}" % varsuffix, thesha256)

  template = template.replace("${VERSION}", version)
  components = ["binutils", "gdb", "gold", "newlib", "gcc", "smallclib", "qemu", "musl", "packages", "python"]

  sources = ""
  for component in components:
    filenameraw = "%s-%s.src.tar.gz" % (component, version)
    filename = "src/%s" % (filenameraw)
    # Size in megabytes
    thesize = os.path.getsize(filename) >> 20
    if thesize == 0:
      thesize = 1
    # md5sum
    themd5 = md5sum(filename)
    # sha256sum
    thesha256 = sha256sum(filename)
    print("%s %s %s %s" %(filename,thesize,themd5,thesha256))
    sources = sources + "<tr><td width=\"200px\"><a href=\"" + filename + "\">" + filenameraw + \
	      "</a></td><td width=\"80px\">[" + str(thesize) + "M]</td><td >md5: <tt>" + \
	      themd5 + "</tt><br>sha256: <tt>" + thesha256 + "</tt></td></tr>\n"


  template = template.replace("${SOURCES}", sources)
  print("Updating %s/nanotemplate/downloads.html" % scriptpath)
  f = open("%s/nanotemplate/downloads.html" % scriptpath, 'w')
  f.write(template)
  f.close()

  # Add a link to this release in the previous releases list
  # for next time around.
  f = open("%s/nanotemplate/downloads.tmpl" % scriptpath, 'r')
  template = f.read()
  f.close()
  download=""
  if template.find ("<!-- ${REL_SUP_" + version[:7] + "} -->") > 0:
    download = "${REL_SUP_" + version[:7] + "} -->\n" + \
               "\t\t<td><a href=\"../" + version + "/downloads.html\">" + version + "</a></td>"
    template = template.replace("${REL_SUP_" + version[:7] + "} -->", download)
  elif template.find ("<!-- ${REL_NEW} -->") > 0:
    download = "${REL_NEW} -->\n" + \
               "\t      <tr>\n" + \
               "\t\t<!-- ${REL_SUP_" + version[:7] + "} -->\n" + \
               "\t\t<td><a href=\"../" + version + "/downloads.html\">" + version + "</a></td>\n" + \
               "\t      </tr>"
    template = template.replace("${REL_NEW} -->", download)
  print("Updating %s/nanotemplate/downloads.tmpl" % scriptpath)
  f = open("%s/nanotemplate/downloads.tmpl" % scriptpath, 'w')
  f.write(template)
  f.close()

if True:
  f = open("%s/nanotemplate/releasenotes.html" % scriptpath, mode='r')
  template = f.read()
  f.close()
  if relnotes:
    print("Reading release notes content from %s" % relnotes)
    f = open(relnotes, mode='r')
    content = f.read().split("*****")
    f.close()
  else:
    content = []

  newtoc = "${TOC} -->\n\t    " + version + "\n"
  newtoc += "\t    &nbsp; <a href=\"#" + version + "NewFeatures\">New Features</a>\n"
  newtoc += "\t    &nbsp; <a href=\"#" + version + "BugFixes\">Bug Fixes</a>\n"
  newtoc += "\t    &nbsp; <a href=\"#" + version + "OtherChanges\">Other Changes</a>\n"
  newtoc += "\t    &nbsp; <a href=\"#" + version + "KnownIssues\">Known Issues</a>\n"
  if os.path.exists ("docs"):
    newtoc += "\t    &nbsp; <a href=\"#" + version + "Docs\">Documentation</a>\n"
    docs=True
  else:
    newtoc += "\t    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</a>\n"
  compver = re.search (r"#([0-9\.\-]*CompVer)", template)
  if compver:
    newtoc += "\t    &nbsp; <a href=\"#" + compver.group(1) + "\">Component Versions</a>\n"
  else:
    newtoc += "\t    &nbsp; <a href=\"#" + version + "CompVer\">Component Versions</a>\n"
  newtoc += "\t    <br />\n"
  newtoc += "\t    <!-- End " + version
  template = template.replace("${TOC}", newtoc)

  newnotes = "${NOTES} -->\n"
  newnotes += "\t\t<h2>Toolchain " + version + "</h2>\n"
  newnotes += "\t\t<h4>Published on " + today.strftime ("%B %d, %Y") + "</h4>\n"
  newnotes += "\t\t<h3 id=\"" + version + "NewFeatures\">" + version + " New Features</h3>\n"
  newnotes += grok_release_content("NewFeatures", content)
  newnotes += "\t\t<h3 id=\"" + version + "BugFixes\">" + version + " Bug Fixes</h3>\n"
  newnotes += grok_release_content("BugFixes", content)
  newnotes += "\t\t<h3 id=\"" + version + "OtherChanges\">" + version + " Other Changes</h3>\n"
  newnotes += grok_release_content("OtherChanges", content)
  newnotes += "\t\t<h3 id=\"" + version + "KnownIssues\">" + version + " Known issues</h3>\n"
  newnotes += grok_release_content("KnownIssues", content)
  if os.path.exists ("docs"):
    found = False
    newnotes += "\t\t<h3 id=\"" + version + "Docs\">" + version + " Documentation Updates</h3>\n"
    newnotes += "\t\t<ul>\n"
    for doc in os.listdir ("docs"):
      if fnmatch.fnmatch(doc, '*.pdf'):
        found = True
        [dname,dver] = os.path.basename(doc).split('0', 1)
        dname = dname.replace('_', ' ')
        if "DN" in dver:
          dver = (dver.split ("DN", 1))[0].replace('_','.')
        else:
          dver = (dver.split (".", 1))[0].replace('_','.')
        newnotes += "\t\t<li><a href=\"../" + version + "/docs/" + doc + "\">" + dname + ", " + dver + "</a></li>\n"
    if not found:
      newnotes += "\t\t<li>None</li>\n"
    newnotes += "\t\t</ul>\n"
  if not compver:
    newnotes += "\t\t<h3 id=\"" + version + "CompVer\">" + version + " Component Versions</h3>\n"
    newnotes += "<table border=0>"
    newnotes += "<tr><th width=\"100px\">Component</th><th>Based on upstream version</th></tr>"
    newnotes += "<tr><td width=\"100px\">FIXME</td><td>FIXME</td></tr>"
    newnotes += "</table>"
  newnotes += "\t\t<!-- End " + version

  template = template.replace("${NOTES}", newnotes)
  print("Updating %s/nanotemplate/releasenotes.html" % scriptpath)
  f = open("%s/nanotemplate/releasenotes.html" % scriptpath, 'w')
  f.write(template)
  f.close()

if True:
  templatedir = os.path.join (scriptpath, "nanotemplate")
  print("Copy release website from %s" % templatedir)
  shutil.copy(os.path.join(templatedir, "index.html"), os.getcwd())
  shutil.copy(os.path.join(templatedir, "license.html"), os.getcwd())
  shutil.copy(os.path.join(templatedir, "releasenotes.html"), os.getcwd())
  shutil.copy(os.path.join(templatedir, "downloads.html"), os.getcwd())
  shutil.copy(os.path.join(templatedir, "support.html"), os.getcwd())
  shutil.copy(os.path.join(templatedir, "style.css"), os.getcwd())
  shutil.copytree(os.path.join(templatedir, "images"), os.path.join(os.getcwd(), "images"))

  print("Fix ownership & permissions")
  if os.stat(os.getcwd()).st_uid != os.getuid():
    ret=subprocess.call (["sudo", "chown", "-R", os.getlogin()+":mipsswrel", os.getcwd()])
  else:
    ret=subprocess.call (["chgrp", "-R", "mipsswrel", os.getcwd()])
  if ret != 0:
    print("ERROR: Failed to change ownership of " + os.getcwd())
  ret = subprocess.call (["chmod", "-R", "g+w,o-w", os.getcwd()])
  if ret != 0:
    print("ERROR: Failed to set permissions on " + os.getcwd())

  mipsswrel_path="/projects/mipsswrel/toolchains/nanomips"
  if os.access(mipsswrel_path, os.X_OK | os.W_OK):
    print("Copy toolchain to " + mipsswrel_path)
    shutil.copytree(os.getcwd(), os.path.join(mipsswrel_path, version))
  else:
    print("No write permissions on %s, not copying toolchain to release area" % mipsswrel_path)

  mipsswinst_path = "/projects/mipssw/toolchains"
  if os.access(mipsswinst_path, os.X_OK | os.W_OK):
    tf = tarfile.open("Codescape.GNU.Tools.Package.%s.for.nanoMIPS.Bare.Metal.CentOS-6.x86_64.tar.gz" % version,
                      'r|gz')
    print("Extracting x86_64 elf toolchain to " + os.path.join(mipsswinst_path, 'nanomips-elf', version))
    if tf:
      tf.extractall(mipsswinst_path)
      subprocess.call (["chmod", "-R", "g+w,o-w", os.path.join(mipsswinst_path, 'nanomips-elf', version)])

    tf = tarfile.open("Codescape.GNU.Tools.Package.%s.for.nanoMIPS.Linux.CentOS-6.x86_64.tar.gz" % version,
                      'r|gz')
    print("Extracting x86_64 linux toolchain to " + os.path.join(mipsswinst_path, 'nanomips-linux-musl',  version))
    if tf:
      tf.extractall(mipsswinst_path)
      subprocess.call (["chmod", "-R", "g+w,o-w", os.path.join(mipsswinst_path, 'nanomips-linux-musl', version)])
  else:
    print("No write permissions on %s, not installing x86_64 toolchains" % mipsswinst_path)

  print("Adding website changes to git")
  ret=subprocess.Popen(["git", "add", "nanotemplate"], cwd = scriptpath)
  if ret == 0:
    ret=subprocess.Popen(["git", "commit", "-m", "\"nanoMIPS toolchain release " + version + "\""], cwd = scriptpath)
  if ret != 0:
    print("ERROR: checking in failed\n")
