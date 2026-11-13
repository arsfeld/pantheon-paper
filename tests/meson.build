# Each unit test is the core compiled with one test file.
foreach name : ['strip', 'layout']
    test(name, executable('test-' + name, core_sources + files('test_' + name + '.vala'), dependencies: core_deps))
endforeach
