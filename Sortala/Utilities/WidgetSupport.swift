//
//  WidgetSupport.swift
//  Sortala
//

import WidgetKit

enum SortalaWidgetKind {
    static let small = "SortalaSmallWidget"
    static let medium = "SortalaMediumWidget"
    static let lockScreen = "SortalaLockScreenWidget"

    static let all = [small, medium, lockScreen]
}

enum SortalaWidgetReloader {
    static func reloadTimelines() {
        for kind in SortalaWidgetKind.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
