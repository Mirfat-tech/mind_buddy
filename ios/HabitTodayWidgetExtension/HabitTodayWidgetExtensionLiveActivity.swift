//
//  HabitTodayWidgetExtensionLiveActivity.swift
//  HabitTodayWidgetExtension
//
//  Created by Mirfat Al-ghaithy on 24/02/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.1, *)
struct HabitTodayWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

@available(iOSApplicationExtension 16.1, *)
struct HabitTodayWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HabitTodayWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
extension HabitTodayWidgetExtensionAttributes {
    fileprivate static var preview: HabitTodayWidgetExtensionAttributes {
        HabitTodayWidgetExtensionAttributes(name: "World")
    }
}

@available(iOSApplicationExtension 17.0, *)
extension HabitTodayWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: HabitTodayWidgetExtensionAttributes.ContentState {
        HabitTodayWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: HabitTodayWidgetExtensionAttributes.ContentState {
         HabitTodayWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

@available(iOSApplicationExtension 17.0, *)
#Preview("Notification", as: .content, using: HabitTodayWidgetExtensionAttributes.preview) {
   HabitTodayWidgetExtensionLiveActivity()
} contentStates: {
    HabitTodayWidgetExtensionAttributes.ContentState.smiley
    HabitTodayWidgetExtensionAttributes.ContentState.starEyes
}
