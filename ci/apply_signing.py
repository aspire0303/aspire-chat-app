import glob
import re
import sys

files = glob.glob("android/app/build.gradle.kts") + glob.glob("android/app/build.gradle")
if not files:
    print("No Android build.gradle found.")
    sys.exit(1)
path = files[0]
text = open(path, encoding="utf-8").read()
is_kts = path.endswith(".kts")

if is_kts:
    block = """
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("SIGN_KEYSTORE_PATH"))
            storePassword = System.getenv("SIGN_STORE_PASSWORD")
            keyAlias = System.getenv("SIGN_KEY_ALIAS")
            keyPassword = System.getenv("SIGN_KEY_PASSWORD")
        }
    }
"""
    text = re.sub(r'signingConfigs\.getByName\("debug"\)', 'signingConfigs.getByName("release")', text)
else:
    block = """
    signingConfigs {
        release {
            storeFile file(System.getenv("SIGN_KEYSTORE_PATH"))
            storePassword System.getenv("SIGN_STORE_PASSWORD")
            keyAlias System.getenv("SIGN_KEY_ALIAS")
            keyPassword System.getenv("SIGN_KEY_PASSWORD")
        }
    }
"""
    text = re.sub(r'signingConfigs\.debug', 'signingConfigs.release', text)

text, n = re.subn(r'(\nandroid\s*\{[^\n]*\n)', lambda m: m.group(1) + block, text, count=1)
ok = n == 1 and ("SIGN_KEYSTORE_PATH" in text) and ('getByName("release")' in text or "signingConfigs.release" in text)
open(path, "w", encoding="utf-8").write(text)
print(text if not ok else "Signing config applied to " + path)
if not ok:
    print("Could not apply the signing config. The build file above is what was found.")
    sys.exit(1)