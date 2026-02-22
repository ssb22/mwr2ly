#!/usr/bin/env python3
"""
Lilypond staff size finder
Silas S. Brown 2026 - public domain - no warranty

Finds the largest staff size that fits within the
page count of minSize using binary search to 1 d.p.
(because larger is better UNLESS more page turns)

Requires pdfinfo (package: poppler-utils)
"""

import sys,os,re,subprocess,tempfile

minSize = 25.2 # you may customise this

def addSetSize(ly,size):
    pattern = r'#\(set-global-staff-size\s+[\d.]+\)'
    version=r'(\\version\s+"[^"]+")'
    add = f'#(set-global-staff-size {size})'
    return re.sub(pattern,add,ly) if re.search(pattern,ly) else re.sub(version,lambda m:m.group()+'\n'+add,ly) if re.search(version,ly) else add + '\n' + ly

def testSize(lyPathname,tempDir,size):
    sys.stderr.write(f"Size {size}: "), sys.stderr.flush()
    tempLy = os.path.join(tempDir,f'test_{size}.ly')
    with open(tempLy,'w') as f: f.write(addSetSize(open(lyPathname,'r').read(), size))
    subprocess.run(['lilypond','-o',os.path.join(tempDir,'output'),tempLy],cwd=tempDir,capture_output=True)
    pages=[int(line.split(':')[1].strip()) for line in subprocess.run(['pdfinfo',os.path.join(tempDir,'output.pdf')],capture_output=True,text=True).stdout.split('\n') if line.startswith('Pages:')][0]
    sys.stderr.write(f"{pages} pages\n"), sys.stderr.flush()
    return pages

def findSize(lyPathname,tempDir):
    L = testSize(lyPathname,tempDir,minSize)
    high,highPages = minSize,L
    while highPages==L:
        high += 5
        highPages = testSize(lyPathname,tempDir,high)
    low,best = minSize,minSize
    while high-low>=0.1:
        mid=round((low+high)/2,1)
        if testSize(lyPathname,tempDir,mid)<=L:
            best,low = mid,round(mid+0.1,1)
        else: high=round(mid-0.1,1)
    if testSize(lyPathname,tempDir,high)<=L: best=high
    return best

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: size-finder [ly-files]\n")
        sys.exit(1)
    for lyPathname in sys.argv[1:]:
        if not os.path.exists(lyPathname):
            sys.stderr.write(f"File not found: {lyPathname}\n")
            sys.exit(1)
    with tempfile.TemporaryDirectory() as tempDir:
        sys.stderr.write(f"Working in {tempDir}\n")
        for lyPathname in sys.argv[1:]:
            size = findSize(lyPathname,tempDir)
            ly=addSetSize(open(lyPathname,'r').read(),size)
            with open(lyPathname, 'w') as f: f.write(ly)
            sys.stderr.write(f"Updated {lyPathname} with staff size {size}\n")

if __name__=='__main__': main()
# ruff: noqa: E401
# ruff: noqa: E701
