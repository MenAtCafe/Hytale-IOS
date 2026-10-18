
import subprocess, sys, os, json
WD = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIG = WD + "/gate2/HytaleClient.orig"
OUT  = WD + "/gate2/work/HytaleClient"
MM   = WD + "/machomorph/machomorph.py"
os.makedirs(WD + "/gate2/work", exist_ok=True)

MAP = {
    "_syslog$DARWIN_EXTSN": "_syslog",
    "_SSLSetCertificateAuthorities": "_SSLSetSessionOption",
}
if len(sys.argv) > 2:
    MAP[sys.argv[1]] = sys.argv[2]

subprocess.run(["python3", MM, ORIG, "-o", OUT, "-p", "iossimulator", "-v", "27.0", "--no-libraries"],
               check=True, capture_output=True)
data = bytearray(open(OUT, "rb").read())
for old, new in MAP.items():
    ob, nb = old.encode(), new.encode()
    if len(nb) > len(ob):
        print("SKIP (longer):", old); continue
    n = data.count(ob)
    data = data.replace(ob, nb + b"\x00" * (len(ob) - len(nb)))
    print(f"{old} -> {new}  ({n} hit(s))")
open(OUT, "wb").write(data)
subprocess.run(["codesign", "-f", "-s", "-", OUT], check=True, capture_output=True)
print("retargeted + signed")
