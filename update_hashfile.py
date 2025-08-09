import subprocess
import sys
import json
from typing import Optional

type Hash = str
type Version = str
type PackageName = str
type HashFile = dict[PackageName, dict[Version, Optional[Hash]]]


def process_output_to_hash(process: subprocess.Popen) -> Hash:
    process.wait()
    if process.stdout is None:
        raise TypeError()

    return process.stdout.read()


def add_package(hashfile: HashFile):
    new_package = sys.argv[2]
    try:
        versions = sys.argv[2].split(",")
    except IndexError:
        versions = [version for p in hashfile.values() for version in p.keys()]

    processes: list[tuple[Version, subprocess.Popen]] = []
    for version in versions:
        processes.append((version, calculate_hash(version, new_package)))

    hashfile[new_package] = {}
    for version, process in processes:
        hashfile[new_package][version] = process_output_to_hash(process)


def add_version(hashfile: HashFile):
    if len(sys.argv) == 4:
        copy_version = sys.argv[2]
        new_version = sys.argv[3]
    else:
        copy_version = None
        new_version = sys.argv[2]

    processes: list[tuple[PackageName, subprocess.Popen]] = []
    for package, package_info in hashfile.items():
        if copy_version is not None and package_info.get(copy_version) is None:
            continue

        processes.append((package, calculate_hash(new_version, package)))

    for package, process in processes:
        hashfile[package][new_version] = process_output_to_hash(process)


def calculate_hash(version: Version, package: PackageName) -> subprocess.Popen:
    subprocess.Popen("nix run ")
    return f"{package}-{version}"


with open("hashfile.json") as hashfile:
    hashfile_data = json.loads(hashfile.read())

match sys.argv[1]:
    case "add-version":
        add_version(hashfile_data)
    case "add-package":
        add_package(hashfile_data)
    case _:
        raise ValueError("Expected `add-version` or `add-package` for first argument")

with open("hashfile.json", "w") as hashfile:
    hashfile.write(json.dumps(hashfile_data))
