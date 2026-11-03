import Foundation
import Testing
@testable import Kikobar

@Suite("Core Data Models Tests")
struct ModelTests {
    @Test("Detects ContentType accurately from URLs and extensions")
    func contentTypeDetection() {
        let imageURL = URL(fileURLWithPath: "/tmp/sample.png")
        #expect(ContentType.from(url: imageURL) == .image)

        let pdfURL = URL(fileURLWithPath: "/tmp/document.pdf")
        #expect(ContentType.from(url: pdfURL) == .document)

        let movieURL = URL(fileURLWithPath: "/tmp/clip.mov")
        #expect(ContentType.from(url: movieURL) == .video)

        let audioURL = URL(fileURLWithPath: "/tmp/song.mp3")
        #expect(ContentType.from(url: audioURL) == .audio)
    }

    @Test("Initializes CollectionCategory with defaults")
    func categoryModel() {
        let category = CollectionCategory(name: "Design", hexColor: "#FF5E7E")
        #expect(category.name == "Design")
        #expect(category.hexColor == "#FF5E7E")
        #expect(category.isExpanded == true)
        #expect(category.itemCount == 0)
    }

    @Test("Initializes CollectionItem correctly")
    func itemModel() {
        let catID = UUID()
        let item = CollectionItem(
            name: "Screenshot.png",
            categoryID: catID,
            contentType: .image,
            storageType: .imported,
            localPath: "/tmp/Screenshot.png"
        )
        #expect(item.name == "Screenshot.png")
        #expect(item.categoryID == catID)
        #expect(item.contentType == .image)
        #expect(item.storageType == .imported)
        #expect(item.isSourceAvailable == true)
    }
}
