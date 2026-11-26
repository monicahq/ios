@testable import Monica
import Testing

@MainActor
struct WelcomeViewModelTests {
    private let repository = InstanceRepository(defaults: temporaryDefaults())

    private func viewModelWithOpenSheet() -> WelcomeViewModel {
        let viewModel = WelcomeViewModel(instanceRepository: repository)
        viewModel.openInstanceSheet()
        return viewModel
    }

    @Test func `shows the default instance with the sheet closed`() {
        let viewModel = WelcomeViewModel(instanceRepository: repository)

        #expect(viewModel.state == WelcomeUiState(instanceURL: defaultInstanceURL))
    }

    @Test func `shows the saved instance`() {
        repository.setURL("https://monica.example.com")

        let viewModel = WelcomeViewModel(instanceRepository: repository)

        #expect(viewModel.state.instanceURL == "https://monica.example.com")
    }

    @Test func `opening the sheet fills the field with the current address`() {
        repository.setURL("https://monica.example.com")
        let viewModel = WelcomeViewModel(instanceRepository: repository)

        viewModel.openInstanceSheet()

        #expect(viewModel.state.sheet == InstanceSheetState(draft: "https://monica.example.com"))
    }

    @Test func `typing changes the draft only`() {
        let viewModel = viewModelWithOpenSheet()

        viewModel.changeDraft("monica.example.com")

        #expect(viewModel.state.sheet?.draft == "monica.example.com")
        #expect(viewModel.state.instanceURL == defaultInstanceURL)
        #expect(repository.url == defaultInstanceURL)
    }

    @Test func `typing while the sheet is closed does nothing`() {
        let viewModel = WelcomeViewModel(instanceRepository: repository)

        viewModel.changeDraft("monica.example.com")

        #expect(viewModel.state.sheet == nil)
    }

    @Test func `saving a valid address stores it, shows it and closes the sheet`() {
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft("monica.example.com/")

        viewModel.saveInstance()

        #expect(viewModel.state == WelcomeUiState(instanceURL: "https://monica.example.com"))
        #expect(repository.url == "https://monica.example.com")
    }

    @Test func `saving an empty field stores the default instance`() {
        repository.setURL("https://monica.example.com")
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft("")

        viewModel.saveInstance()

        #expect(viewModel.state.instanceURL == defaultInstanceURL)
        #expect(repository.url == defaultInstanceURL)
    }

    @Test func `saving an invalid address keeps the sheet open with an error`() {
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft("not an address")

        viewModel.saveInstance()

        #expect(viewModel.state.sheet == InstanceSheetState(draft: "not an address", isError: true, refusals: 1))
        #expect(viewModel.state.instanceURL == defaultInstanceURL)
        #expect(repository.url == defaultInstanceURL)
    }

    @Test func `saving the same invalid address again counts another refusal`() {
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft("not an address")
        viewModel.saveInstance()

        viewModel.saveInstance()

        #expect(viewModel.state.sheet?.refusals == 2)
        #expect(viewModel.state.sheet?.isError == true)
    }

    @Test func `typing again clears the error`() {
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft("not an address")
        viewModel.saveInstance()

        viewModel.changeDraft("monica.example.com")

        #expect(viewModel.state.sheet?.isError == false)
    }

    @Test func `saving while the sheet is closed does nothing`() {
        let viewModel = WelcomeViewModel(instanceRepository: repository)

        viewModel.saveInstance()

        #expect(viewModel.state == WelcomeUiState(instanceURL: defaultInstanceURL))
    }

    @Test func `reset puts the default address in the field without saving`() {
        repository.setURL("https://monica.example.com")
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft("not an address")
        viewModel.saveInstance()

        viewModel.resetDraft()

        #expect(viewModel.state.sheet?.draft == defaultInstanceURL)
        #expect(viewModel.state.sheet?.isError == false)
        #expect(viewModel.state.instanceURL == "https://monica.example.com")
        #expect(repository.url == "https://monica.example.com")
    }

    @Test func `dismissing closes the sheet without saving`() {
        let viewModel = viewModelWithOpenSheet()
        viewModel.changeDraft("https://monica.example.com")

        viewModel.dismissInstanceSheet()

        #expect(viewModel.state == WelcomeUiState(instanceURL: defaultInstanceURL))
        #expect(repository.url == defaultInstanceURL)
    }
}
