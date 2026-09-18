//
//  HomeViewModel.swift
//  AllergyScanner
//
//  Created by Dina Bravo Stojakovic on 10/06/2025.
//

import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var allergens: [String] = []
    
    private let userDefaultsKey = "savedAllergens"
    private var defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadAllergens()
    }
    
    private func loadAllergens() {
        if let saved = defaults.stringArray(forKey: userDefaultsKey) {
            allergens = saved
        } else {
            allergens = []
        }
    }
    
    private func saveAllergens() {
        defaults.set(allergens, forKey: userDefaultsKey)
    }
    
    /// Adds a new allergen (lowercased) if not empty or duplicate
    func add(_ allergen: String) {
        let trimmed = allergen.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lower = trimmed.lowercased()
        guard !allergens.map({ $0.lowercased() }).contains(lower) else { return }
        allergens.append(trimmed)
        saveAllergens()
    }
    
    /// Removes an allergen at the given offsets
    func remove(at offsets: IndexSet) {
        allergens.remove(atOffsets: offsets)
        saveAllergens()
    }

    /// Removes a specific allergen (used by the per-row delete button).
    func remove(_ allergen: String) {
        allergens.removeAll { $0 == allergen }
        saveAllergens()
    }
}
