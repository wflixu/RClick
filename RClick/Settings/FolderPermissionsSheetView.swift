//
//  FolderPermissionsSheetView.swift
//  RClick
//
//  Created by Claude on 2026/07/12.
//

import SwiftUI

struct FolderPermissionsSheetView: View {
    @ObservedObject var bookmarkManager: BookmarkManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text(AppLocalization.localized("Folder Permissions"))
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)

            if bookmarkManager.authorizedDirectories.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(AppLocalization.localized("No folders authorized"))
                        .foregroundColor(.secondary)
                    Text(AppLocalization.localized("Authorize folders to let RClick create, delete, and manage files in them."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 40)
            } else {
                List {
                    ForEach(bookmarkManager.authorizedDirectories, id: \.path) { url in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            Text(url.path)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                bookmarkManager.removeDirectory(url)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                            .help(AppLocalization.localized("Remove folder permission"))
                        }
                    }
                }
                .frame(minHeight: 200)
            }

            Divider()

            HStack {
                Button {
                    Task { @MainActor in
                        _ = await bookmarkManager.addDirectory()
                    }
                } label: {
                    Label(AppLocalization.localized("Add a Folder…"), systemImage: "plus")
                }

                Spacer()

                Button(AppLocalization.localized("Done")) {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
        }
        .frame(width: 480, height: 360)
    }
}
