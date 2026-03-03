This folder contains WidgetKit source for the iOS home screen widget:

- `HabitTodayWidget.swift`

To make it active in iOS builds, create/add a Widget Extension target in Xcode
and include this file in that target. Use app group:

- `group.com.example.mind_buddy`

The Flutter side writes widget data through `home_widget` keys:

- `habits_done_today`
- `habits_total_today`
- `habits_widget_title`
- `habits_widget_subtitle`

