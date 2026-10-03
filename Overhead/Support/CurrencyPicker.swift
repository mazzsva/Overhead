//
//  CurrencyPicker.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 03/10/26.
//

import SwiftUI

struct CurrencyPicker: View {
    var title: LocalizedStringKey = "Currency"
    @Binding var selection: String

    @Environment(\.locale) private var locale

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(locale.sortedCurrencyCodes(including: selection), id: \.self) { currencyCode in
                Text(locale.currencyName(for: currencyCode))
                    .tag(currencyCode)
            }
        }
        .pickerStyle(.navigationLink)
    }
}

#Preview {
    @Previewable @State var selection = "EUR"
    NavigationStack {
        Form {
            CurrencyPicker(selection: $selection)
        }
    }
}
