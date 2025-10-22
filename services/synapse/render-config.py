#!/usr/bin/env python3
"""
Render a Jinja2 template to an output file.

- Loads environment variables into `env` mapping available in templates.
- Loads every file under /run/secrets and /etc/synapse/secrets.d (if present)
  into the `secret` mapping by filename (no extension).
- Writes output and ensures file permissions 0600.
Usage:
  ./render-config.py /data/homeserver.yaml.j2 /data/homeserver.yaml
"""
import os
import sys
import stat
from pathlib import Path
from jinja2 import Environment, FileSystemLoader

def main():
    if len(sys.argv) != 3:
        print("Usage: render-config.py <template.j2> <output.yaml>")
        sys.exit(2)

    template_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    env = Environment(loader=FileSystemLoader(template_path.parent))
    template = env.get_template(template_path.name)

    # env variables mapping available to template as 'env'
    env_vars = dict(os.environ)

    rendered = template.render(env=env_vars)

    # write atomically
    tmp = output_path.with_suffix(output_path.suffix + ".tmp")
    tmp.write_text(rendered, encoding='utf-8')

    # set secure permissions: owner read/write only
    tmp.chmod(0o600)
    tmp.rename(output_path)

if __name__ == "__main__":
    main()
