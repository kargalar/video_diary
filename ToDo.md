ana sayfadaki streak ile ilgili şeyler ayarlardan akaptılabilsin.

takvimde bottom streak durumunu göster. gaçıncı günde olduğunu

takvimi sağa sola kaydırarak da gidilsin.

start recording altta tek kalmalı. streak ve ayarları taşı.

○ Google drive video yedeklene
○ Settingsdekinselte all butonu kaldır
○ Spalash screende sadece transparan icon. Bu sayede karanlık tema sorun olmaz"

════════ Exception caught by foundation library ════════════════════════════════
The following assertion was thrown while dispatching notifications for DiaryViewModel:
setState() or markNeedsBuild() called during build.
This \_InheritedProviderScope<DiaryViewModel?> widget cannot be marked as needing to build because the framework is already in the process of building widgets. A widget can be marked as needing to be built during the build phase only if one of its ancestors is currently building. This exception is allowed because the framework builds parent widgets before children, which means a dirty descendant will always be built. Otherwise, the framework might not visit this widget during this build phase.
The widget on which setState() or markNeedsBuild() was called was: \_InheritedProviderScope<DiaryViewModel?>
value: Instance of 'DiaryViewModel'
listening to value
The widget which was currently being built when the offending call was made was: Builder

When the exception was thrown, this was the stack:
#0 Element.markNeedsBuild.<anonymous closure> (package:flutter/src/widgets/framework.dart:5167:9)
framework.dart:5167
#1 Element.markNeedsBuild (package:flutter/src/widgets/framework.dart:5179:6)
framework.dart:5179
#2 \_InheritedProviderScopeElement.markNeedsNotifyDependents (package:provider/src/inherited_provider.dart:590:5)
inherited_provider.dart:590
#3 ChangeNotifier.notifyListeners (package:flutter/src/foundation/change_notifier.dart:435:24)
change_notifier.dart:435
#4 DiaryViewModel.\_updateState (package:video_diary/features/diary/viewmodel/diary_view_model.dart:35:5)
diary_view_model.dart:35
#5 DiaryViewModel.load (package:video_diary/features/diary/viewmodel/diary_view_model.dart:39:5)
diary_view_model.dart:39
#6 \_DiaryPageState.initState (package:video_diary/features/diary/view/diary_page.dart:25:8)
diary_page.dart:25
#7 StatefulElement.\_firstBuild (package:flutter/src/widgets/framework.dart:5710:55)
framework.dart:5710
#8 ComponentElement.mount (package:flutter/src/widgets/framework.dart:5573:5)
framework.dart:5573
... Normal element mounting (260 frames)
#268 Element.inflateWidget (package:flutter/src/widgets/framework.dart:4411:20)
framework.dart:4411
#269 MultiChildRenderObjectElement.inflateWidget (package:flutter/src/widgets/framework.dart:6971:36)
framework.dart:6971
#270 MultiChildRenderObjectElement.mount (package:flutter/src/widgets/framework.dart:6983:32)
framework.dart:6983
... Normal element mounting (471 frames)
#741 SingleChildWidgetElementMixin.mount (package:nested/nested.dart:222:11)
nested.dart:222
... Normal element mounting (7 frames)
#748 \_InheritedProviderScopeElement.mount (package

video kayıt yatay mı oluyor dikey mi.
