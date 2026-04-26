//
//  SortalaWidgetBundle.swift
//  SortalaWidget
//
//  Entry point for the widget extension.
//  Registers all available widgets in a single WidgetBundle.

import SwiftUI
import WidgetKit

@main
struct SortalaWidgetBundle: WidgetBundle {
    var body: some Widget {
        SortalaSmallWidget()
        SortalaMediumWidget()
        SortalaLockScreenWidget()
    }
}
