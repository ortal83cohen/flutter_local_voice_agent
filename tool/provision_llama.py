#!/usr/bin/env python3
"""Explicit build-time provisioning of the optional CPU LLM source."""
import argparse
import hashlib
from pathlib import Path
import shutil
import tarfile
import tempfile
import urllib.request

REVISION = '987498f4592a76897863cf53711dce38380c082b'
SHA256 = 'a2365b66223589de852d923870de6257ac59ebe0c1e337da7c1d5c3f7d60d838'

def provision(destination, archive=None):
    destination=Path(destination).resolve()
    if destination.exists(): raise ValueError('Destination must not exist')
    with tempfile.TemporaryDirectory(prefix='flva-llama-') as temp:
        temp=Path(temp)
        file=Path(archive) if archive else temp/'source.tar.gz'
        if not archive:
            urllib.request.urlretrieve('https://codeload.github.com/ggml-org/llama.cpp/tar.gz/'+REVISION,file)
        if hashlib.sha256(file.read_bytes()).hexdigest()!=SHA256: raise ValueError('Source SHA-256 mismatch')
        with tarfile.open(file) as tar: tar.extractall(temp,filter='data')
        source=temp/('llama.cpp-'+REVISION)
        shutil.copytree(source,destination)
        (destination/'FLVA_REVISION').write_text(REVISION+'\n')
    print('Verified llama.cpp source '+REVISION+' at '+str(destination))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination')
    parser.add_argument('--archive')
    args=parser.parse_args()
    provision(args.destination,args.archive)
