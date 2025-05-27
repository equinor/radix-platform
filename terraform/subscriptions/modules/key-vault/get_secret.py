#!/usr/bin/env python3
import json
import subprocess
import sys
import urllib.request

def get_fallback_ip():
    try:
        with urllib.request.urlopen("https://ipinfo.io/ip") as response:
            return response.read().decode().strip()
    except Exception:
        return "unknown"

def format_output(value):
    # Split by comma, strip whitespace, and encode as JSON string
    parts = [v.strip() for v in value.split(",")]
    return json.dumps({"value": json.dumps(parts)})

def main():
    try:
        params = json.load(sys.stdin)
        vault = params.get("vault")
        name = params.get("name")
    except Exception:
        print(format_output(get_fallback_ip()))
        return

    if not vault or not name:
        print(format_output(get_fallback_ip()))
        return

    try:
        result = subprocess.run(
          [
              "az", "keyvault", "secret", "show",
              "--vault-name", vault,
              "--name", name,
              "--query", "value",
              "-o", "tsv"
          ],
          stdout=subprocess.PIPE,
          stderr=subprocess.DEVNULL,
          check=True,
          text=True
        )
        value = result.stdout.strip()
    except subprocess.CalledProcessError:
        value = get_fallback_ip()

    print(format_output(value))

if __name__ == "__main__":
    main()
