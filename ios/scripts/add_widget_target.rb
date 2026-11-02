# Добавить в Runner.xcodeproj расширение виджетов SmitWidgets (iOS 17+) и встроить его в приложение.
# Запускается в CI перед сборкой (ios-release.yml): проект в репозитории остаётся без расширения,
# чтобы не править project.pbxproj руками. Повторный запуск ничего не меняет.
#   PP_NAME, WIDGET_PP_NAME — имена профилей подписи приложения и виджетов.
require 'xcodeproj'

Dir.chdir(File.expand_path('..', __dir__))   # ios/
proj = Xcodeproj::Project.open('Runner.xcodeproj')
if proj.targets.any? { |t| t.name == 'SmitWidgets' }
  puts 'SmitWidgets уже в проекте'
  exit 0
end

m = File.read('../pubspec.yaml').match(/^version:\s*([\d.]+)\+(\d+)/)
abort 'нет version в pubspec.yaml' unless m
marketing, build = m[1], m[2]
team = '6LX2W6558K'

app = proj.targets.find { |t| t.name == 'Runner' }
ext = proj.new_target(:app_extension, 'SmitWidgets', :ios, '17.0', proj.products_group, :swift)

group = proj.main_group.new_group('SmitWidgets', 'SmitWidgets')
Dir['SmitWidgets/*.swift'].sort.each do |f|
  ext.add_file_references([group.new_reference(File.basename(f))])
end
%w[Info.plist SmitWidgets.entitlements].each { |f| group.new_reference(f) }

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_NAME'] = 'SmitWidgets'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'ru.smit34.smitBilling.SmitWidgets'
  s['INFOPLIST_FILE'] = 'SmitWidgets/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = 'SmitWidgets/SmitWidgets.entitlements'
  s['MARKETING_VERSION'] = marketing
  s['CURRENT_PROJECT_VERSION'] = build
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['SWIFT_VERSION'] = '5.0'
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['DEVELOPMENT_TEAM'] = team
  s['CODE_SIGN_STYLE'] = 'Manual'
  s['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
  s['PROVISIONING_PROFILE_SPECIFIER'] = ENV.fetch('WIDGET_PP_NAME', '')
end

# приложение: свой профиль на цель (профиль в командной строке достался бы и расширению),
# WidgetKit — слабой ссылкой (приложение работает с iOS 13, WidgetKit есть с iOS 14)
app.build_configurations.each do |c|
  s = c.build_settings
  s['DEVELOPMENT_TEAM'] = team
  s['CODE_SIGN_STYLE'] = 'Manual'
  s['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
  s['PROVISIONING_PROFILE_SPECIFIER'] = ENV.fetch('PP_NAME', '')
  flags = Array(s['OTHER_LDFLAGS'] || '$(inherited)')
  s['OTHER_LDFLAGS'] = flags + ['-weak_framework', 'WidgetKit']
end

app.add_dependency(ext)
embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(ext.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
# встраивание — до «Thin Binary» Flutter, иначе Xcode находит цикл зависимостей
app.build_phases.delete(embed)
thin = app.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' } || app.build_phases.size
app.build_phases.insert(thin, embed)

proj.save
puts "SmitWidgets добавлен: #{marketing} (#{build}), фазы Runner: #{app.build_phases.map(&:display_name).join(' → ')}"
