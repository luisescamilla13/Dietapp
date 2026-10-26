import FoodVisionKit
import PhotosUI
import SwiftUI

/// Picks or takes a photo and lists the foods in it. Choosing one searches for it.
struct PhotoSuggestionsSection: View {
    let onChoose: (FoodSuggestion) -> Void

    @Environment(\.foodRecognizer) private var foodRecognizer
    @State private var model: PhotoSuggestionsModel?
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var thumbnail: UIImage?
    @State private var isShowingCamera = false

    var body: some View {
        Section {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose a photo", systemImage: "photo.on.rectangle")
            }
            if CameraPicker.isAvailable {
                Button("Take a photo", systemImage: "camera") { isShowingCamera = true }
            }
            if let model {
                results(model)
            }
        } header: {
            Text("From a photo")
        } footer: {
            Text("Dietapp suggests what the photo may show, and you choose what to search for. The photo stays on your device.")
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { data in
                isShowingCamera = false
                if let data { imageData = data }
            }
            .ignoresSafeArea()
        }
        .task(id: pickerItem) {
            guard let pickerItem else { return }
            imageData = try? await pickerItem.loadTransferable(type: Data.self)
        }
        // Recognizing in a task tied to the photo cancels it when another photo replaces it.
        .task(id: imageData) {
            if model == nil {
                model = PhotoSuggestionsModel(recognizer: foodRecognizer)
            }
            guard let imageData, let model else { return }
            thumbnail = await UIImage(data: imageData)?.byPreparingThumbnail(ofSize: CGSize(width: 160, height: 160))
            await model.recognize(imageData)
        }
    }

    @ViewBuilder
    private func results(_ model: PhotoSuggestionsModel) -> some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .recognizing:
            HStack(spacing: 12) {
                photo
                ProgressView()
                Text("Looking at your photo…")
                    .foregroundStyle(.secondary)
            }
        case .suggestions(let suggestions):
            photo
            ForEach(suggestions) { suggestion in
                Button {
                    onChoose(suggestion)
                } label: {
                    LabeledContent(suggestion.displayName) {
                        Text(suggestion.confidence, format: .percent.precision(.fractionLength(0)))
                    }
                }
                .accessibilityHint("Searches for this food")
            }
        case .noFood:
            HStack(spacing: 12) {
                photo
                Text("No food found in that photo. Try a closer one, or search above.")
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 8))
                .accessibilityLabel("Your photo")
        }
    }
}
