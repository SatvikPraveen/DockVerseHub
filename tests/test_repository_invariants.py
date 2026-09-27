# Location: tests/test_repository_invariants.py
"""Repository-level invariants that used to be ad-hoc shell in CI.

Every check here is something a reader relies on: links resolve, labs and
concepts have READMEs, Dockerfiles do not invoke tools their base image
lacks, and the statistics the README advertises match the tree.
"""

import re
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv"}


def _files(pattern: str):
    return [p for p in ROOT.rglob(pattern) if p.is_file() and not (set(p.parts) & SKIP_DIRS)]


LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s#]+)(?:#[^)]*)?\)")


def _relative_links(md: Path):
    for m in LINK_RE.finditer(md.read_text(encoding="utf-8", errors="replace")):
        target = m.group(1)
        if target.startswith(("http://", "https://", "mailto:", "tel:")):
            continue
        yield target


# --------------------------------------------------------------------------- #
# Documentation links
# --------------------------------------------------------------------------- #

TOP_LEVEL_DOCS = [
    ROOT / "README.md",
    ROOT / "research" / "README.md",
    ROOT / "research" / "METHODOLOGY.md",
    ROOT / "docs" / "INDEX.md",
    ROOT / "docs" / "GETTING_STARTED.md",
]


@pytest.mark.parametrize(
    "doc", [d for d in TOP_LEVEL_DOCS if d.exists()], ids=lambda p: str(p.relative_to(ROOT))
)
def test_relative_links_resolve(doc: Path):
    missing = [t for t in _relative_links(doc) if not (doc.parent / t).exists()]
    assert not missing, f"{doc.relative_to(ROOT)} has dead links: {missing}"


# --------------------------------------------------------------------------- #
# Structure
# --------------------------------------------------------------------------- #


def test_every_lab_has_readme_and_docker_artifacts():
    labs = sorted(p for p in (ROOT / "labs").glob("lab_*") if p.is_dir())
    assert len(labs) >= 8
    for lab in labs:
        assert (lab / "README.md").is_file(), lab.name
        assert (lab / "docker-compose.yml").is_file() or (lab / "Dockerfile").is_file(), lab.name


def test_every_concept_has_readme():
    concepts = sorted(p for p in (ROOT / "concepts").glob("[0-9]*") if p.is_dir())
    assert len(concepts) >= 13
    for c in concepts:
        assert (c / "README.md").is_file(), c.name


def test_readme_counts_match_tree():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    labs = len([p for p in (ROOT / "labs").glob("lab_*") if p.is_dir()])
    concepts = len([p for p in (ROOT / "concepts").glob("[0-9]*") if p.is_dir()])
    assert f"Labs-{labs}-" in readme, "README lab badge is stale"
    assert f"Concepts-{concepts}-" in readme, "README concept badge is stale"


def test_no_stray_brace_named_files():
    stray = [p for p in _files("*") if "{" in p.name or "}" in p.name]
    assert not stray, stray


# --------------------------------------------------------------------------- #
# Dockerfile sanity
# --------------------------------------------------------------------------- #

MINIMAL_BASE = re.compile(r"^FROM\s+\S*(?:-slim|-alpine|distroless)\S*", re.M | re.I)
INSTALLS_CURL = re.compile(
    # allow backslash-newline continuations inside the install command
    r"(apt-get|apk|yum|dnf|microdnf)\s+(?:-\S+\s+)*(?:install|add)(?:[^\n]|\\\n)*\bcurl\b",
    re.I,
)
HEALTHCHECK_CURL = re.compile(r"HEALTHCHECK[^\n]*(?:\\\n[^\n]*)*\bcurl\b", re.I)


@pytest.mark.parametrize(
    "dockerfile", _files("Dockerfile*"), ids=lambda p: str(p.relative_to(ROOT))
)
def test_healthcheck_tool_is_present_in_minimal_images(dockerfile: Path):
    text = dockerfile.read_text(encoding="utf-8", errors="replace")
    # Only the final stage matters for HEALTHCHECK; take the text after the last FROM.
    final_stage = text[text.rfind("\nFROM ") + 1 :] if "\nFROM " in text else text
    if MINIMAL_BASE.search(final_stage) and HEALTHCHECK_CURL.search(final_stage):
        assert INSTALLS_CURL.search(final_stage), (
            f"{dockerfile.relative_to(ROOT)}: HEALTHCHECK uses curl but the minimal base image does not ship it; "
            "install curl or use a Python/wget probe"
        )


RUN_HEREDOC = re.compile(r"^RUN\s.*<<-?\s*[\"']?[A-Za-z_]+", re.M)


@pytest.mark.parametrize(
    "dockerfile", _files("Dockerfile*"), ids=lambda p: str(p.relative_to(ROOT))
)
def test_heredoc_dockerfiles_declare_syntax(dockerfile: Path):
    """RUN heredocs need dockerfile frontend >= 1.4; pin it so older builders fail loudly."""
    text = dockerfile.read_text(encoding="utf-8", errors="replace")
    if RUN_HEREDOC.search(text):
        assert text.lstrip().startswith(
            "# syntax="
        ), f"{dockerfile.relative_to(ROOT)} uses RUN heredocs but has no '# syntax=' directive"


@pytest.mark.parametrize(
    "dockerfile", _files("Dockerfile*"), ids=lambda p: str(p.relative_to(ROOT))
)
def test_dockerfile_has_from(dockerfile: Path):
    text = dockerfile.read_text(encoding="utf-8", errors="replace")
    assert re.search(r"^\s*FROM\s+", text, re.M), f"{dockerfile} has no FROM"


# --------------------------------------------------------------------------- #
# Attribution
# --------------------------------------------------------------------------- #


def test_mailmap_canonical_identity():
    mailmap = (ROOT / ".mailmap").read_text(encoding="utf-8")
    assert "satvikpraveen707@gmail.com" in mailmap
    assert "action@github.com" in mailmap


def test_citation_file_is_well_formed():
    cff = ROOT / "CITATION.cff"
    assert cff.is_file()
    text = cff.read_text(encoding="utf-8")
    for key in ("cff-version", "title", "authors", "repository-code", "license"):
        assert f"{key}:" in text, key


# --------------------------------------------------------------------------- #
# YAML well-formedness (every file, not a sample)
# --------------------------------------------------------------------------- #


class _TolerantLoader(yaml.SafeLoader):
    """SafeLoader that accepts application tags such as GitLab's !reference."""


_TolerantLoader.add_multi_constructor("!", lambda loader, suffix, node: None)


@pytest.mark.parametrize(
    "path",
    sorted(_files("*.yml") + _files("*.yaml")),
    ids=lambda p: str(p.relative_to(ROOT)),
)
def test_yaml_parses(path: Path):
    with path.open(encoding="utf-8") as fh:
        list(yaml.load_all(fh, Loader=_TolerantLoader))


@pytest.mark.parametrize(
    "dockerfile", _files("Dockerfile*"), ids=lambda p: str(p.relative_to(ROOT))
)
def test_syntax_directive_is_first_line(dockerfile: Path):
    """BuildKit only honours parser directives before any other line (comments included)."""
    lines = dockerfile.read_text(encoding="utf-8", errors="replace").splitlines()
    idx = [i for i, line in enumerate(lines) if re.match(r"#\s*syntax\s*=", line)]
    assert not idx or idx == [
        0
    ], f"{dockerfile.relative_to(ROOT)}: '# syntax=' on line {idx[0] + 1}; it is ignored unless it is line 1"
