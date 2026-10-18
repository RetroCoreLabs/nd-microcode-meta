"""MkDocs hook: links that MkDocs does not follow.

The site uses the repository root as its docs folder, so README.md and the
pages in docs/ link to files that are not pages (LICENSE, src/..., the
submodule). This hook rewrites such a relative link to the same file on
GitHub, and logs a WARNING for a link whose target does not exist at all, so
`mkdocs build --strict` fails on it. It also handles href="..." in raw HTML,
which MkDocs does not rewrite. Fenced code blocks are left alone.
"""

import logging
import os
import posixpath
import re

log = logging.getLogger("mkdocs.hooks.links")

MD_LINK = re.compile(r"(\]\()([^)\s]+)((?:\s+\"[^\"]*\")?\))")
HTML_LINK = re.compile(r"(href=\")([^\"]+)(\")")
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")


def _fix(target, page, files, root, repo_url):
    if SCHEME.match(target) or target.startswith(("#", "/", "mailto:")):
        return target
    path, hash_, fragment = target.partition("#")
    if not path:
        return target
    here = posixpath.dirname(page.file.src_uri)
    resolved = posixpath.normpath(posixpath.join(here, path))
    known = files.get_file_from_path(resolved)
    if known is not None and known.inclusion.is_included():
        return target  # a page or a file of the site: MkDocs handles it
    on_disk = os.path.join(root, *resolved.split("/"))
    if os.path.isdir(on_disk):
        return f"{repo_url}/tree/main/{resolved}"
    if os.path.isfile(on_disk):
        return f"{repo_url}/blob/main/{resolved}" + (hash_ + fragment)
    log.warning("%s links to '%s', which does not exist", page.file.src_uri, target)
    return target


def on_page_markdown(markdown, page, config, files):
    root = config["docs_dir"]
    repo_url = config["repo_url"].rstrip("/")
    out = []
    in_fence = False
    for line in markdown.split("\n"):
        if line.lstrip().startswith(("```", "~~~")):
            in_fence = not in_fence
            out.append(line)
            continue
        if in_fence:
            out.append(line)
            continue
        line = MD_LINK.sub(
            lambda m: m.group(1) + _fix(m.group(2), page, files, root, repo_url) + m.group(3),
            line,
        )
        line = HTML_LINK.sub(
            lambda m: m.group(1) + _fix(m.group(2), page, files, root, repo_url) + m.group(3),
            line,
        )
        out.append(line)
    return "\n".join(out)
