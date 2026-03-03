//
//  HabitTodayWidgetExtensionBundle.swift
//  HabitTodayWidgetExtension
//
//  Created by Mirfat Al-ghaithy on 24/02/2026.
//

import WidgetKit
import SwiftUI

@main
struct HabitTodayWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        HabitTodayWidgetExtension()
        if #available(iOSApplicationExtension 16.1, *) {
            HabitTodayWidgetExtensionLiveActivity()
        }
    }
}
