package `in`.koreatech.koin.feature.user.ui.signup.userinfo.general

sealed class SignUpGeneralSideEffect {
    data object SignUpSuccess : SignUpGeneralSideEffect()
    data class SignUpFailure(val message: String) : SignUpGeneralSideEffect()
}
