#  nsis packaging

nsis_required = get_option('nsis').allowed() and not get_option('nsis').auto()
makensis = find_program('makensis', required: nsis_required)

nsi_conf = configuration_data()
nsi_conf.merge_from(cdata)
nsi_conf.set('BUILD_LUA_TRUE', lua_dep.found() and get_option('lua').allowed() ? '' : ';')
nsi_conf.set('BUILD_SKINS_TRUE', skins2_feasible ? '' : ';')
nsi_conf.set('HAVE_WIN64_TRUE',  have_win64 ? '' : ';')
nsi_conf.set('HAVE_WIN64_FALSE', have_win64 ? ';' : '')
nsi_conf.set('HAVE_ARM64_TRUE',  host_machine.cpu_family() == 'aarch64' or host_machine.cpu() == 'arm64' ? '' : ';')
nsi_conf.set('HAVE_ARM64_FALSE', host_machine.cpu_family() == 'aarch64' or host_machine.cpu() == 'arm64' ? ';' : '')
nsi_conf.set('PROGRAMFILES', have_win64 ? 'PROGRAMFILES64' : 'PROGRAMFILES')
nsi_conf.set('HAVE_NLS_TRUE', nsi_conf.get('ENABLE_NLS', 0) == 1 ? '' : ';')
# redesign: brand layer (root meson.build brand_profiles)
nsi_conf.set('BRAND_PRODUCT_NAME', brand['product_name'])
nsi_conf.set('BRAND_COMPANY', brand['company'])
nsi_conf.set('BRAND_EXE', brand['exe_name'] + '.exe')
nsi_conf.set('BRAND_ICON_FILE', brand['icon_file'])
nsi_conf.set('BRAND_WEBSITE', brand['website'])
nsi_conf.set('BRAND_FINISH_LINK', brand['finish_link'])
nsi_conf.set('BRAND_REGKEY', brand['regkey'])
nsi_conf.set('BRAND_INSTALL_DIR', brand['install_dir'])
nsi_conf.set('BRAND_PRODUCT_ID', brand['product_id'])
nsi_conf.set('BRAND_NSIS_BITMAP_TRUE', brand['nsis_bitmap_true'])
nsi_conf.set('BRAND_PROGID', brand['progid'])
nsi_conf.set('BRAND_INTERNAL_NAME', brand['internal_name'])
nsi_conf.set('BRAND_VERSION', brand_version)
nsi_conf.set('BRAND_VERSION_MAJOR', brand_version_major)
nsi_conf.set('BRAND_VERSION_MINOR', brand_version_minor)

nsProcess_cargs = ['-D_UNICODE=1', '-DUNICODE=1']
if not have_win64
    nsProcess_cargs += '-D_WIN32_IE=0x0601'
endif
nsProcess_link_args = ['-static-libgcc']

# TODO use nsis-pluginapi if possible to be compatible with the system makensis
# it provides the matching pluginapi.h and a library to link with

nsProcess_sources = files('nsProcess/nsProcess.c', 'nsProcess/nsis/pluginapi.c')
nsProcess_src = []
nsProcess_obj = []
if host_machine.cpu_family() != 'x86'
    # nsProcess.dll needs to be a 32-bit DLL
    # with clang we can link a i686 DLL via -target i686-w64-mingw32
    if cc.has_link_argument(['--target=i686-w64-mingw32'], required: nsis_required)
        nsProcess_link_args += '--target=i686-w64-mingw32'

        x86_compiler = generator(find_program('i686-w64-mingw32-gcc'),
          output: ['@BASENAME@.obj'],
          arguments: ['@INPUT@', '-c', '-o', '@OUTPUT@', nsProcess_cargs])

        nsProcess_obj += x86_compiler.process(nsProcess_sources)
    endif
else
    # TODO always use this mode when we switch to a native .exe installer
    # for each architecture
    nsProcess_src = nsProcess_sources
endif
nsProcess = shared_library('nsProcess',
                           nsProcess_src,
                           c_args: nsProcess_cargs,
                           link_args: nsProcess_link_args,
                           objects: nsProcess_obj,
                           vs_module_defs: 'nsProcess.def',
                           name_prefix: '',
                           link_language: 'c',  # avoid using nasm linker and miss the .dll.a
                           install: true,
                           install_dir: 'NSIS')

vlc_nsi = configure_file(
  input: 'vlc.win32.nsi.in',
  output: 'vlc.win32.nsi',
  configuration: nsi_conf,
  format: 'cmake@',
  install: true,
  install_dir: '.',
)

spad_nsi = configure_file(
  input: 'spad.nsi.in',
  output: 'spad.nsi',
  configuration: nsi_conf,
  format: 'cmake@',
  install: true,
  install_dir: '.',
)

install_data('nsProcess.nsh',    install_dir : 'NSIS')
install_data('vlc_branding.bmp', install_dir : 'NSIS')
# redesign: brand layer, Cone's installer images and texts
if get_option('brand') == 'public'
    install_data(vlc_src_root / 'extras/package/win32/brand/public/nsis-welcome.bmp',
                 vlc_src_root / 'extras/package/win32/brand/public/nsis-header.bmp',
                 install_dir : 'NSIS')
    meson.add_install_script('brand-languages.sh', 'languages', brand['product_name'])
endif
install_subdir('languages',      install_dir : '.')
install_subdir('helpers',        install_dir : '.')

if have_win_store
  nsi_script_dir = 'vlc-' + winstaller_suffix + '-uwp'
elif cc.compiles(ucrt_version_test, name: 'compiles with Universal C Runtime')
  nsi_script_dir = 'vlc-' + winstaller_suffix + '-ucrt'
else
  nsi_script_dir = 'vlc-' + winstaller_suffix
endif

if makensis.found()
    spad_nsis = custom_target(
        command: [makensis, nsi_script_dir / 'spad.nsi'],
        input: spad_nsi,
        output: 'spad-setup.exe', # real name but located in installed folder
        build_by_default: false,
        console: true)

    vlc_nsis = custom_target(
        command: [makensis, nsi_script_dir / 'vlc.win32.nsi'],
        input: vlc_nsi,
        output: brand['internal_name'] + '-' + vlc_version + '-' + winstaller_suffix + '.exe', # real name but root build folder
        build_by_default: false,
        console: true,
        depends: nsProcess)

    alias_target('package-win32-exe', spad_nsis, vlc_nsis)
endif
