import SwiftUI
import UIKit
import AuthenticationServices

struct AccountView: View {
    @ObservedObject private var session = AuthSession.shared
    @AppStorage(AppLanguage.storageKey) private var languageRaw = "en"
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }

    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isRegister = false
    @State private var busy = false
    @State private var error: String?
    @State private var info: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            QSBackground()
            ScrollView {
                if session.isSignedIn { signedIn } else { signedOut }
            }
            if busy { ProcessingOverlay(text: L.t("processing", lang)) }
        }
        .navigationTitle(L.t("account", lang))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Signed in

    private var signedIn: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64)).foregroundStyle(LinearGradient.brand)
            if let n = session.user?.name, !n.isEmpty {
                Text(n).font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(Palette.ink)
            }
            Text(session.user?.email ?? "").foregroundStyle(Palette.sub)

            VStack(spacing: 0) {
                Button { session.signOut() } label: {
                    rowLabel(L.t("sign_out", lang), "rectangle.portrait.and.arrow.right", tint: Palette.ink)
                }
                Divider().padding(.leading, 16)
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    rowLabel(L.t("delete_account", lang), "trash", tint: Palette.danger)
                }
            }
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.separator, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.top, 6)
        }
        .padding(.vertical, 30)
        .alert(L.t("delete_account", lang), isPresented: $showDeleteConfirm) {
            Button(L.t("delete_account", lang), role: .destructive) { Task { await run { try await session.deleteAccount() } } }
            Button(L.t("cancel", lang), role: .cancel) {}
        } message: {
            Text(L.t("delete_account_msg", lang))
        }
    }

    // MARK: Signed out

    private var signedOut: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 46)).foregroundStyle(Palette.brand)
                Text(L.t("account", lang)).font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(Palette.ink)
                Text(L.t("account_intro", lang))
                    .font(.subheadline).foregroundStyle(Palette.sub)
                    .multilineTextAlignment(.center).padding(.horizontal, 30)
            }
            .padding(.top, 20)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await handleApple(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)

            Button { googleFlow() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "g.circle.fill").font(.title3)
                    Text(L.t("continue_google", lang)).font(.system(.headline, design: .rounded))
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.separator, lineWidth: 1))
            }
            .padding(.horizontal, 20)

            HStack {
                line; Text(L.t("or_email", lang)).font(.caption).foregroundStyle(Palette.faint); line
            }.padding(.horizontal, 24).padding(.vertical, 4)

            VStack(spacing: 10) {
                if isRegister { field(L.t("your_name", lang), text: $name) }
                field(L.t("email", lang), text: $email, keyboard: .emailAddress)
                secureField(L.t("password", lang), text: $password)
            }
            .padding(.horizontal, 20)

            Button { Task { await emailFlow() } } label: {
                Text(isRegister ? L.t("create_account", lang) : L.t("sign_in", lang))
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)

            Button { isRegister.toggle(); error = nil } label: {
                Text(isRegister ? L.t("have_account", lang) : L.t("no_account", lang))
                    .font(.subheadline.weight(.medium)).foregroundStyle(Palette.brand)
            }
            if !isRegister {
                Button { Task { await forgot() } } label: {
                    Text(L.t("forgot_password", lang)).font(.caption).foregroundStyle(Palette.sub)
                }
            }

            if let error { message(error, color: Palette.danger, icon: "exclamationmark.triangle.fill") }
            if let info { message(info, color: Palette.success, icon: "checkmark.circle.fill") }
        }
        .padding(.bottom, 30)
    }

    // MARK: Bits

    private var line: some View { Rectangle().fill(Palette.separator).frame(height: 1) }

    private func field(_ ph: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(ph, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(14)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.separator, lineWidth: 1))
    }
    private func secureField(_ ph: String, text: Binding<String>) -> some View {
        SecureField(ph, text: text)
            .padding(14)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.separator, lineWidth: 1))
    }
    private func rowLabel(_ title: String, _ icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 24)
            Text(title).font(.system(.body, design: .rounded))
            Spacer()
        }
        .foregroundStyle(tint).padding(16)
    }
    private func message(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text).font(.footnote)
        }
        .foregroundStyle(color).padding(.horizontal, 24).multilineTextAlignment(.center)
    }

    // MARK: Actions

    private func run(_ op: @escaping () async throws -> Void) async {
        busy = true; error = nil; info = nil
        do { try await op() }
        catch let e as AuthError { if case .cancelled = e {} else { error = e.errorDescription } }
        catch { self.error = error.localizedDescription }
        busy = false
    }

    private func emailFlow() async {
        let e = email.trimmingCharacters(in: .whitespaces)
        guard e.contains("@"), !password.isEmpty else { error = L.t("field_required", lang); return }
        await run {
            if isRegister { try await session.register(name: name.trimmingCharacters(in: .whitespaces), email: e, password: password) }
            else { try await session.signInWithEmail(e, password: password) }
        }
    }

    private func forgot() async {
        let e = email.trimmingCharacters(in: .whitespaces)
        guard e.contains("@") else { error = L.t("field_required", lang); return }
        await run { try await session.requestPasswordReset(email: e) }
        if error == nil { info = L.t("reset_email_sent", lang) }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                error = L.t("auth_generic_error", lang); return
            }
            let n = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            await run { try await session.signInWithApple(identityToken: token, name: n.isEmpty ? nil : n) }
        case .failure(let e):
            if (e as? ASAuthorizationError)?.code == .canceled { return }
            error = e.localizedDescription
        }
    }

    private func googleFlow() {
        #if canImport(GoogleSignIn)
        GoogleSignInBridge.signIn(lang: lang) { result in
            switch result {
            case .success(let (idToken, gname)):
                Task { await run { try await session.signInWithGoogle(idToken: idToken, name: gname) } }
            case .failure(let e):
                if case AuthError.cancelled = e {} else { error = e.localizedDescription }
            }
        }
        #else
        error = L.t("google_setup_needed", lang)
        #endif
    }
}
