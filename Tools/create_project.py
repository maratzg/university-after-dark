#!/usr/bin/env python3
"""Generate the dependency-free Xcode app and hosted XCTest project."""
from pathlib import Path
import hashlib
ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'UniversityAfterDark.xcodeproj'
PROJECT.mkdir(exist_ok=True)
objects = {}

def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name, value): objects[uid(name)] = value; return uid(name)
def quote(s): return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"') + '"'
def array(values): return '(' + ', '.join(values) + (',' if values else '') + ')'
def settings(values): return '{' + ' '.join(f'{k} = {quote(v)};' for k,v in values.items()) + '}'

appSources = sorted(ROOT.glob('Core/*.swift')) + sorted(ROOT.glob('Application/*.swift'))
testSources = sorted(ROOT.glob('Tests/*.swift'))
resources = sorted(ROOT.glob('Resources/*'))
fileRefs = {}
for file in appSources + testSources + resources:
    name = str(file.relative_to(ROOT))
    typ = 'folder' if file.is_dir() else 'sourcecode.swift' if file.suffix == '.swift' else 'text.json' if file.suffix == '.json' else 'file'
    fileRefs[name] = add('ref:' + name, '{isa = PBXFileReference; lastKnownFileType = ' + typ + '; path = ' + quote(name) + '; sourceTree = "<group>";}')
appProduct = add('appProduct', '{isa = PBXFileReference; explicitFileType = wrapper.application; path = UniversityAfterDark.app; sourceTree = BUILT_PRODUCTS_DIR;}')
testProduct = add('testProduct', '{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = UniversityAfterDarkTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;}')

def phase(name, kind, files):
    builds = []
    for file in files:
        path = str(file.relative_to(ROOT))
        builds.append(add('build:' + name + path, '{isa = PBXBuildFile; fileRef = ' + fileRefs[path] + ';}'))
    return add(name, '{isa = ' + kind + '; buildActionMask = 2147483647; files = ' + array(builds) + '; runOnlyForDeploymentPostprocessing = 0;}')
appSourcePhase = phase('appSources', 'PBXSourcesBuildPhase', appSources)
resourcePhase = phase('resources', 'PBXResourcesBuildPhase', resources)
testPhase = phase('testSources', 'PBXSourcesBuildPhase', testSources)
frameworkPhase = phase('frameworks', 'PBXFrameworksBuildPhase', [])
products = add('products', '{isa = PBXGroup; name = Products; sourceTree = "<group>"; children = ' + array([appProduct, testProduct]) + ';}')
groups = []
for directory in ['Application', 'Core', 'Resources', 'Tests']:
    refs = [ref for name,ref in fileRefs.items() if name.startswith(directory + '/')]
    groups.append(add('group:' + directory, '{isa = PBXGroup; name = ' + directory + '; sourceTree = "<group>"; children = ' + array(refs) + ';}'))
mainGroup = add('mainGroup', '{isa = PBXGroup; sourceTree = "<group>"; children = ' + array(groups + [products]) + ';}')

common = dict(MACOSX_DEPLOYMENT_TARGET='15.0', SDKROOT='macosx', SWIFT_VERSION='5.0', CLANG_ENABLE_MODULES='YES', CLANG_ENABLE_OBJC_ARC='YES', GCC_WARN_UNUSED_VARIABLE='YES', SWIFT_STRICT_CONCURRENCY='targeted')
app = dict(PRODUCT_BUNDLE_IDENTIFIER='com.local.UniversityAfterDark', PRODUCT_NAME='$(TARGET_NAME)', INFOPLIST_FILE='Info.plist', CODE_SIGN_STYLE='Manual', CODE_SIGN_IDENTITY='-', DEVELOPMENT_TEAM='', ENABLE_APP_SANDBOX='YES', ENABLE_HARDENED_RUNTIME='YES', COMBINE_HIDPI_IMAGES='YES', LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/../Frameworks', SUPPORTED_PLATFORMS='macosx')
tests = dict(PRODUCT_BUNDLE_IDENTIFIER='com.local.UniversityAfterDarkTests', PRODUCT_NAME='$(TARGET_NAME)', GENERATE_INFOPLIST_FILE='YES', CODE_SIGN_STYLE='Manual', CODE_SIGN_IDENTITY='-', TEST_HOST='$(BUILT_PRODUCTS_DIR)/UniversityAfterDark.app/Contents/MacOS/UniversityAfterDark', BUNDLE_LOADER='$(TEST_HOST)', LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks')

def configlist(name, values):
    configs = []
    for mode in ['Debug', 'Release']:
        modeSettings = dict(values)
        modeSettings.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode == 'Debug' else '-O', DEBUG_INFORMATION_FORMAT='dwarf' if mode == 'Debug' else 'dwarf-with-dsym')
        if mode == 'Debug': modeSettings.update(ENABLE_TESTABILITY='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG', ONLY_ACTIVE_ARCH='YES')
        configs.append(add(name + mode, '{isa = XCBuildConfiguration; name = ' + mode + '; buildSettings = ' + settings(modeSettings) + ';}'))
    return add(name + 'list', '{isa = XCConfigurationList; buildConfigurations = ' + array(configs) + '; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
projectConfig = configlist('project', common)
appConfig = configlist('app', app)
testConfig = configlist('tests', tests)
proxy = add('proxy', '{isa = PBXContainerItemProxy; containerPortal = ' + uid('project') + '; proxyType = 1; remoteGlobalIDString = ' + uid('app') + '; remoteInfo = UniversityAfterDark;}')
dependency = add('dependency', '{isa = PBXTargetDependency; target = ' + uid('app') + '; targetProxy = ' + proxy + ';}')
appTarget = add('app', '{isa = PBXNativeTarget; name = UniversityAfterDark; productName = UniversityAfterDark; productType = "com.apple.product-type.application"; productReference = ' + appProduct + '; buildConfigurationList = ' + appConfig + '; buildPhases = ' + array([appSourcePhase, frameworkPhase, resourcePhase]) + '; buildRules = (); dependencies = ();}')
testTarget = add('test', '{isa = PBXNativeTarget; name = UniversityAfterDarkTests; productName = UniversityAfterDarkTests; productType = "com.apple.product-type.bundle.unit-test"; productReference = ' + testProduct + '; buildConfigurationList = ' + testConfig + '; buildPhases = ' + array([testPhase]) + '; buildRules = (); dependencies = ' + array([dependency]) + ';}')
add('project', '{isa = PBXProject; attributes = {LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; BuildIndependentTargetsInParallel = YES; TargetAttributes = {' + appTarget + ' = {CreatedOnToolsVersion = 16.0;}; ' + testTarget + ' = {CreatedOnToolsVersion = 16.0; TestTargetID = ' + appTarget + ';};};}; buildConfigurationList = ' + projectConfig + '; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = ' + mainGroup + '; productRefGroup = ' + products + '; projectDirPath = ""; projectRoot = ""; targets = ' + array([appTarget, testTarget]) + ';}')
(PROJECT / 'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(f'{k} = {v};' for k,v in objects.items()) + '\n}; rootObject = ' + uid('project') + ';}\n')
schemes = PROJECT / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{appTarget}" BuildableName="UniversityAfterDark.app" BlueprintName="UniversityAfterDark" ReferencedContainer="container:UniversityAfterDark.xcodeproj"/>'
testRef = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{testTarget}" BuildableName="UniversityAfterDarkTests.xctest" BlueprintName="UniversityAfterDarkTests" ReferencedContainer="container:UniversityAfterDark.xcodeproj"/>'
(schemes / 'UniversityAfterDark.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{testRef}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print('Generated native macOS app + hosted XCTest target and shared scheme.')
