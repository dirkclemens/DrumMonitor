//
//  ViewContainer.swift
//  DrumMonitor
//
//  Created by Dirk Clemens on 29.11.25.
//

import SwiftUI

struct ViewContainer<Content: View>: View {
        let title: String
        let footer: String
        let content: Content

        init(title: String, footer: String, @ViewBuilder content: () -> Content) {
            self.title = title
            self.footer = footer
            self.content = content()
        }

        var body: some View {
            VStack(spacing: 0) {
                // Title Bar
                HStack {
                    Text(title)
                        .padding(.leading, 12)
//                        .font(.title2)
                        .bold()
                    Spacer()
                .padding()
                }
                .background(Color.gray.opacity(0.12))

                // Content Area
                content
                    .padding()
                    

                // Footer Bar
                HStack {
                    Text(footer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(Color.gray.opacity(0.12))
            }
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
//            .shadow(radius: 4)
        }
    }
