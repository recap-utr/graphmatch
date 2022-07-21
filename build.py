# https://github.com/aotuai/example-cython-poetry-pypi
# https://stackoverflow.com/a/63679316
# https://github.com/davidcortesortuno/poetry_cython_proj/blob/4fdb9bf5bde47cbc3ca2e351e9054ceccbc6c533

import multiprocessing as mp
import typing as t
from os.path import sep as path_sep
from pathlib import Path

from Cython.Build import cythonize
from Cython.Distutils.build_ext import new_build_ext as build_ext
from numpy import get_include as get_numpy_include
from setuptools import Distribution, Extension

# from setuptools.command.build_ext import build_ext as build_ext_type

SOURCE_DIR = Path("./graphmatch")
CYTHON_BUILD_DIR = Path("./cython_build")
BUILD_DIR = Path("./build")

# This function will be executed in setup.py:
def collect_extensions() -> t.List[Extension]:
    extensions: t.List[Extension] = []

    for file in SOURCE_DIR.rglob("*.pyx"):
        module_path = file.with_suffix("")
        module_name = str(module_path).replace(path_sep, ".")

        extensions.append(
            Extension(
                module_name,
                [str(file)],
                include_dirs=[get_numpy_include()],
                language="c++",
                libraries=[],
                extra_compile_args=[],
                define_macros=[("NPY_NO_DEPRECATED_API", "NPY_1_7_API_VERSION")],
            )
        )

    # with open("./log.txt", "w") as f:
    #     f.write(str(extensions))

    return extensions


def run_cythonize(extensions: t.List[Extension]) -> t.List[Extension]:
    return cythonize(
        extensions,
        build_dir=str(CYTHON_BUILD_DIR),
        annotate=False,
        nthreads=mp.cpu_count() * 2,
        language_level=3,
        force=True,
    )


def build(setup_kwargs: t.MutableMapping[str, t.Any]):
    extensions = collect_extensions()

    extensions.append(
        Extension(
            "munkres.munkres",
            ["munkres/munkres.pyx", "munkres/cpp/Munkres.cpp"],
            include_dirs=[get_numpy_include(), "munkres/cpp"],
            language="c++",
        )
    )

    cyton_extensions = run_cythonize(extensions)

    dist = Distribution({"name": "graphmatch", "ext_modules": cyton_extensions})

    # cmd = t.cast(build_ext_type, build_ext(dist))
    cmd = build_ext(dist)
    cmd.ensure_finalized()  # type: ignore
    cmd.run()  # type: ignore
    cmd.copy_extensions_to_source()  # type: ignore

    return setup_kwargs


if __name__ == "__main__":
    build({})
