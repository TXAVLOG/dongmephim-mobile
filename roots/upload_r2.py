import os
import sys
import mimetypes
import boto3
from botocore.config import Config

# R2 configuration updated to 'dongmephim' bucket
ENDPOINT = "https://a02f960a2fae3ac4715bd8cea865c820.r2.cloudflarestorage.com"
BUCKET = "dongmephim"
ACCESS_KEY = "023f65176c9712382d2656d393aa8df2"
SECRET_KEY = "d86c8bed052c12dbcf7576ca8495e1df3b3462855b71cefc3eebb58666b09f35"
PUBLIC_PREFIX = "https://pub-ffb3837c19c940af8cc1bc7f2682fd70.r2.dev"


def main():
    if len(sys.argv) < 2:
        print("[-] Usage: python upload_r2.py <file_path>")
        sys.exit(1)
        
    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(f"[-] Error: File not found: {file_path}")
        sys.exit(1)
        
    file_name = os.path.basename(file_path)
    # Upload to root of the bucket for direct link access
    key = file_name
    
    try:
        s3 = boto3.client(
            service_name='s3',
            endpoint_url=ENDPOINT,
            aws_access_key_id=ACCESS_KEY,
            aws_secret_access_key=SECRET_KEY,
            config=Config(signature_version='s3v4'),
            region_name='us-east-1'
        )
    except Exception as e:
        print(f"[-] Error initializing R2 Client: {e}")
        sys.exit(1)
        
    print(f"[*] Uploading: {file_name} -> {BUCKET}/{key} ...")
    
    content_type, _ = mimetypes.guess_type(file_path)
    if not content_type:
        content_type = 'application/octet-stream'
        
    try:
        extra_args = {'ContentType': content_type}
        s3.upload_file(file_path, BUCKET, key, ExtraArgs=extra_args)
        
        public_url = f"{PUBLIC_PREFIX}/{key}"
        print(f"[+] Success: {file_name}")
        print(f"[RESULT_URL] {public_url}")
    except Exception as e:
        print(f"[-] Failed to upload {file_name}: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
