package `in`.koreatech.koin.domain.util.regex

import java.security.MessageDigest
import java.security.NoSuchAlgorithmException
import java.util.regex.Pattern

object PasswordUtil {
    // 허용되는 특수문자 클래스 본체 (기존 FILTER_PASSWORD에서 verbatim 추출, 33개 문자)
    // 원본: `₩~!@#$%<>^&*()\-=+_?:;"',.{}|\[\]/\\
    private const val SPECIAL_CHARS_CLASS = """`₩~!@#$%<>^&*()\-=+_?:;"',.{}|\[\]/\\"""

    private val FILTER_PASSWORD =
        """^(?=.*[a-zA-Z])(?=.*[$SPECIAL_CHARS_CLASS])(?=.*[0-9])[a-zA-Z0-9$SPECIAL_CHARS_CLASS]{6,18}${'$'}"""
    val PASSWORD_REGEX: Pattern = Pattern.compile(FILTER_PASSWORD)

    private const val FILTER_CONTAIN_ALPHABET = """.*[a-zA-Z].*"""
    val CONTAIN_ALPHABET_REGEX: Pattern = Pattern.compile(FILTER_CONTAIN_ALPHABET)

    private const val FILTER_CONTAIN_NUMBER = """.*[0-9].*"""
    val CONTAIN_NUMBER_REGEX: Pattern = Pattern.compile(FILTER_CONTAIN_NUMBER)

    private val FILTER_CONTAIN_SYMBOL = """.*[$SPECIAL_CHARS_CLASS].*"""
    val CONTAIN_SYMBOL_REGEX: Pattern = Pattern.compile(FILTER_CONTAIN_SYMBOL)

    // 비밀번호가 사용 가능한지 체크하는 메서드, 특수문자 1개 이상, 6~18
    fun isPasswordValidate(password: String): Boolean {
        return PASSWORD_REGEX.matcher(password).matches()
    }

    fun isContainAlphabet(password: String): Boolean {
        return CONTAIN_ALPHABET_REGEX.matcher(password).matches()
    }

    fun isContainNumber(password: String): Boolean {
        return CONTAIN_NUMBER_REGEX.matcher(password).matches()
    }

    fun isContainSymbol(password: String): Boolean {
        return CONTAIN_SYMBOL_REGEX.matcher(password).matches()
    }

    private fun hashString(
        message: String,
        algorithm: String
    ): String {
        return try {
            val digest = MessageDigest.getInstance(algorithm)
            digest.update(message.toByteArray(Charsets.UTF_8))
            val hashedBytes = digest.digest()

            // Create Hex String using joinToString for efficiency
            // 부호 확장 방지: 0xFF and 마스킹으로 하위 8비트만 취함
            hashedBytes.joinToString("") { "%02x".format(it.toInt() and 0xFF) }
        } catch (ex: NoSuchAlgorithmException) {
            ""
        }
    }

    fun generateSHA256(message: String): String {
        return hashString(message, "SHA-256")
    }
}
