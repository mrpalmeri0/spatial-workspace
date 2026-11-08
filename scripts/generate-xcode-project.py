#!/usr/bin/env python3
"""Generate the dependency-free native Xcode project from the checked-in sources."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[1]
project = root / 'RayNeoWorkspace.xcodeproj'
project.mkdir(exist_ok=True)
def load_env(path):
    data = {}
    if path.exists():
        for raw in path.read_text().splitlines():
            line = raw.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, value = line.split('=', 1)
            data[key.strip()] = value.strip().strip('"')
    return data
cfg = load_env(root / 'Config' / 'release.env')
def c(key, default):
    return cfg.get(key) or default
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def q(text): return '"' + str(text).replace('\\','\\\\').replace('"','\\"') + '"'
objects = {}
def obj(key, contents): objects[uid(key)] = contents; return uid(key)
def array(items): return '(' + ', '.join(items) + ',)' if items else '()'
mac = sorted((root/'Sources').glob('*.swift')) + sorted((root/'Shared').glob('*.swift'))
phone = sorted((root/'iPhone').glob('*.swift')) + sorted((root/'Shared').glob('*.swift'))
refs = {}
localizations = sorted((root/'Resources').glob('*.lproj'))
for path in localizations:
    rel = str(path.relative_to(root))
    refs[rel] = obj('ref:'+rel, f'isa = PBXFileReference; lastKnownFileType = folder; path = {q(rel)}; sourceTree = "<group>";')
for path in sorted(set(mac + phone + [root/'Sources/VirtualDisplayBridge.h', root/'Assets/AppIcon.icns'])):
    rel = str(path.relative_to(root))
    kind = 'sourcecode.swift' if path.suffix == '.swift' else 'sourcecode.c.h' if path.suffix == '.h' else 'image.icns'
    refs[rel] = obj('ref:'+rel, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {q(rel)}; sourceTree = "<group>";')
products = []
targets = []
for name, files, platform, info in [('RayNeoWorkspace', mac, 'macosx', 'Config/Mac-Info.plist'), ('RayNeoRemote', phone, 'iphoneos', 'Config/iPhone-Info.plist')]:
    product = obj('product:'+name, f'isa = PBXFileReference; explicitFileType = wrapper.application; path = {name}.app; sourceTree = BUILT_PRODUCTS_DIR;')
    products.append(product)
    builds = [obj('build:'+name+str(f), f'isa = PBXBuildFile; fileRef = {refs[str(f.relative_to(root))]};') for f in files]
    sources = obj('sources:'+name, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(builds)}; runOnlyForDeploymentPostprocessing = 0;')
    resources = [obj('locale:'+name+path.name, f'isa = PBXBuildFile; fileRef = {refs[str(path.relative_to(root))]};') for path in localizations]
    if platform == 'macosx': resources.append(obj('icon:'+name, f'isa = PBXBuildFile; fileRef = {refs["Assets/AppIcon.icns"]};'))
    resourcesID = obj('resources:'+name, f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {array(resources)}; runOnlyForDeploymentPostprocessing = 0;')
    frameworks = obj('frameworks:'+name, 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    configs = []
    is_mac = platform == 'macosx'
    bundle_id = c('BUNDLE_ID_MAC', 'local.rayneo.workspace.dev') if is_mac else c('BUNDLE_ID_IPHONE', 'local.rayneo.remote')
    display_name = c('DISPLAY_NAME_MAC', 'RayNeo Workspace') if is_mac else c('DISPLAY_NAME_IPHONE', 'RayNeo Remote')
    category = c('CATEGORY_MAC', 'public.app-category.productivity') if is_mac else c('CATEGORY_IPHONE', 'public.app-category.productivity')
    for config in ['Debug', 'Release']:
        settings = {'SDKROOT':platform, 'SWIFT_VERSION':'5.0', 'SWIFT_STRICT_CONCURRENCY':'targeted',
            'PRODUCT_NAME':'$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER':bundle_id,
            'PRODUCT_DISPLAY_NAME':display_name, 'APP_CATEGORY':category, 'APP_COPYRIGHT':c('COPYRIGHT','© 2026 Cristian Palmeri'),
            'INFOPLIST_FILE':info, 'CODE_SIGN_STYLE':'Automatic',
            'CURRENT_PROJECT_VERSION':c('BUILD_NUMBER','4'), 'MARKETING_VERSION':c('MARKETING_VERSION','0.11.0'),
            'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O', 'ENABLE_APP_SANDBOX':'NO',
            'CLANG_ENABLE_MODULES':'YES', 'SWIFT_EMIT_LOC_STRINGS':'YES', 'DEBUG_INFORMATION_FORMAT':'dwarf',
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if config=='Debug' else ''}
        if is_mac:
            settings.update(MACOSX_DEPLOYMENT_TARGET='26.0', ARCHS='arm64', SWIFT_OBJC_BRIDGING_HEADER='Sources/VirtualDisplayBridge.h', CODE_SIGN_STYLE='Manual', CODE_SIGN_ENTITLEMENTS='Config/Mac.entitlements')
            if config=='Release':
                # Distribuzione diretta notarizzata: Hardened Runtime + Developer ID.
                settings.update(ENABLE_HARDENED_RUNTIME='YES', CODE_SIGN_IDENTITY=c('DEVELOPER_ID_APPLICATION','Developer ID Application'), DEVELOPMENT_TEAM=c('TEAM_ID',''))
            else:
                settings.update(CODE_SIGN_IDENTITY='RayNeo Workspace Local Development')
        else:
            settings.update(IPHONEOS_DEPLOYMENT_TARGET='17.0', TARGETED_DEVICE_FAMILY='1,2', SUPPORTED_PLATFORMS='iphoneos iphonesimulator', SUPPORTS_MACCATALYST='NO')
        configs.append(obj('config:'+name+config, 'isa = XCBuildConfiguration; name = '+config+'; buildSettings = {'+' '.join(q(k)+' = '+q(v)+';' for k,v in settings.items())+'};'))
    configList = obj('configs:'+name, f'isa = XCConfigurationList; buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;')
    target = obj('target:'+name, f'isa = PBXNativeTarget; buildConfigurationList = {configList}; buildPhases = {array([sources,frameworks,resourcesID])}; buildRules = (); dependencies = (); name = {name}; productName = {name}; productReference = {product}; productType = "com.apple.product-type.application";')
    targets.append(target)
    schemeDir = project/'xcshareddata/xcschemes'; schemeDir.mkdir(parents=True,exist_ok=True)
    reference=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:RayNeoWorkspace.xcodeproj"/>'
    (schemeDir/f'{name}.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
productsGroup = obj('products', f'isa = PBXGroup; children = {array(products)}; name = Products; sourceTree = "<group>";')
groups=[]
for directory in ['Sources','Shared','iPhone','Assets','Resources']:
    groups.append(obj('group:'+directory, f'isa = PBXGroup; children = {array([v for k,v in refs.items() if k.startswith(directory+"/")])}; name = {directory}; sourceTree = "<group>";'))
mainGroup = obj('group:root', f'isa = PBXGroup; children = {array(groups+[productsGroup])}; sourceTree = "<group>";')
configs = [obj('project:'+c, f'isa = XCBuildConfiguration; name = {c}; buildSettings = {{ ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; }};') for c in ['Debug','Release']]
configList = obj('configs:project', f'isa = XCConfigurationList; buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;')
projectID = obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2700; }}; buildConfigurationList = {configList}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (it, en, Base); mainGroup = {mainGroup}; productRefGroup = {productsGroup}; projectDirPath = ""; projectRoot = ""; targets = {array(targets)};')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = { '+v+' };' for k,v in objects.items())+'\n}; rootObject = '+projectID+'; }\n')
print(project)
