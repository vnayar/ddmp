project('ddmp', 'd',
    meson_version: '>=0.42',
    license: 'MIT',
    version: '0.0.1'
)

project_soversion = '0'

#
# Dependencies
#
pkgc = import('pkgconfig')

#
# Sources
#
ddmp_src = [
    'source/ddmp/match.d',
    'source/ddmp/patch.d',
    'source/ddmp/util.d',
    'source/ddmp/diff.d'
]

src_dir = include_directories('source/')

#
# Targets
#
ddmp_lib = library('ddmp',
        [ddmp_src],
        include_directories: [src_dir],
        install: true,
        version: meson.project_version(),
        soversion: project_soversion
)
pkgc.generate(name: 'ddmp',
              libraries: ddmp_lib,
              subdirs: 'd/ddmp',
              version: meson.project_version(),
              description: 'Diff-Patch-Match library for D.'
)

# to allow others to easily use this as a subproject
ddmp_dep = declare_dependency(
    link_with: [ddmp_lib],
    include_directories: [src_dir]
)

#
# Install
#
install_subdir('source/ddmp/', install_dir: 'include/d/ddmp/')

#
# Tests
#
ddmp_test_exe = executable('ddmp-test',
        ['test/source/app.d'],
        include_directories: [src_dir],
        link_with: [ddmp_lib]
)
test('ddmp-test', ddmp_test_exe)
