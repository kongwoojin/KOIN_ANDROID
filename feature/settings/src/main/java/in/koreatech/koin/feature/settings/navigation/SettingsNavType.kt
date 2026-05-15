package `in`.koreatech.koin.feature.settings.navigation

import kotlinx.serialization.Serializable

@Serializable
sealed class SettingsNavType {
    @Serializable
    data object SettingsRoute : SettingsNavType()
}
