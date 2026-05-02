package `in`.koreatech.koin.domain.usecase.user

import `in`.koreatech.koin.domain.util.regex.PasswordUtil
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class VerifyPasswordFormatUseCaseTest {
    private lateinit var useCase: VerifyPasswordFormatUseCase

    @Before
    fun setUp() {
        useCase = VerifyPasswordFormatUseCase()
    }

    @Test
    fun `비밀번호에 영어가 포함되었는가`() {
        val password = "password"
        val result = useCase.invoke(password)
        assertTrue(result.isIncludeEnglish)
    }

    @Test
    fun `비밀번호에 영어가 존재하지 않는 경우`() {
        val password = "1234"
        val result = useCase.invoke(password)
        assertFalse(result.isIncludeEnglish)
    }

    @Test
    fun `비밀번호에 숫자가 포함되었는가`() {
        val password = "password123"
        val result = useCase.invoke(password)
        assertTrue(result.isIncludeNumber)
    }

    @Test
    fun `비밀번호에 숫자가 존재하지 않는 경우`() {
        val password = "password"
        val result = useCase.invoke(password)
        assertFalse(result.isIncludeNumber)
    }

    @Test
    fun `비밀번호에 기호가 포함되었는가`() {
        val password = "password!"
        val result = useCase.invoke(password)
        assertTrue(result.isIncludeSymbol)
    }

    @Test
    fun `비밀번호에 기호가 존재하지 않는 경우`() {
        val password = "password1234"
        val result = useCase.invoke(password)
        assertFalse(result.isIncludeSymbol)
    }

    @Test
    fun `비밀번호 길이가 6에서 18자가 아닐 경우`() {
        val password = "pass"
        val result = useCase.invoke(password)
        assertFalse(result.isValidLength)
    }

    @Test
    fun `비밀번호 길이가 6자인 경우`() {
        val password = "passwd"
        val result = useCase.invoke(password)
        assertTrue(result.isValidLength)
    }

    @Test
    fun `비밀번호 길이가 18자인 경우`() {
        val password = "passwdpasswdpasswd"
        val result = useCase.invoke(password)
        assertTrue(result.isValidLength)
    }

    // 경계 케이스: isIncludeSymbol 검증
    @Test
    fun `비밀번호에 공백이 포함된 경우 기호로 인식하지 않는다`() {
        val password = "abcde1 "
        val result = useCase.invoke(password)
        assertFalse(result.isIncludeSymbol)
    }

    @Test
    fun `비밀번호에 탭이 포함된 경우 기호로 인식하지 않는다`() {
        val password = "abcde1\t"
        val result = useCase.invoke(password)
        assertFalse(result.isIncludeSymbol)
    }

    @Test
    fun `비밀번호에 이모지가 포함된 경우 기호로 인식하지 않는다`() {
        val password = "abcde😀"
        val result = useCase.invoke(password)
        assertFalse(result.isIncludeSymbol)
    }

    @Test
    fun `비밀번호에 화이트리스트 특수문자(@)가 포함된 경우 기호로 인식한다`() {
        val password = "abcde1@"
        val result = useCase.invoke(password)
        assertTrue(result.isIncludeSymbol)
    }

    @Test
    fun `비밀번호에 화이트리스트 특수문자_괄호열기_가 포함된 경우 기호로 인식한다`() {
        val password = "abcde1["
        val result = useCase.invoke(password)
        assertTrue(result.isIncludeSymbol)
    }

    // 두 경로 정합성 검증
    @Test
    fun `화이트리스트에 없는 공백은 isIncludeSymbol과 isPasswordValidate 양쪽에서 모두 특수문자로 인정되지 않는다`() {
        val password = "abcde1 "
        val result = useCase.invoke(password)
        // UI 피드백: 공백은 특수문자가 아님
        assertFalse(result.isIncludeSymbol)
        // 실제 유효성: 공백은 화이트리스트에 없으므로 통과 불가
        assertFalse(PasswordUtil.isPasswordValidate(password))
    }

    @Test
    fun `화이트리스트 특수문자는 isIncludeSymbol과 isPasswordValidate 양쪽에서 모두 일관되게 특수문자로 인정된다`() {
        val password = "abcde1!"
        val result = useCase.invoke(password)
        // UI 피드백: 화이트리스트 문자(!)는 특수문자로 인정
        assertTrue(result.isIncludeSymbol)
        // 실제 유효성: 영문 + 숫자 + 화이트리스트 특수문자 + 길이 충족 → 통과
        assertTrue(PasswordUtil.isPasswordValidate(password))
    }

    // 정규식 문자열 동일성 검증 (PLAN 체크리스트)
    @Test
    fun `PASSWORD_REGEX 정규식 문자열이 올바르게 생성되었다`() {
        // specialCharsClass: PasswordUtil.kt:11의 SPECIAL_CHARS_CLASS와 동일한 raw string
        val specialCharsClass = """`₩~!@#$%<>^&*()\-=+_?:;"',.{}|\[\]/\\"""
        val expectedPattern =
            """^(?=.*[a-zA-Z])(?=.*[$specialCharsClass])(?=.*[0-9])[a-zA-Z0-9$specialCharsClass]{6,18}$"""
        assertEquals(expectedPattern, PasswordUtil.PASSWORD_REGEX.pattern())
    }

    @Test
    fun `CONTAIN_SYMBOL_REGEX가 FILTER_PASSWORD와 동일한 화이트리스트 기준을 사용한다`() {
        // 화이트리스트에 있는 문자는 양쪽 정규식 모두 매칭되어야 함
        val whitelistSymbols = listOf(
            "`", "₩", "~", "!", "@", "#", "$", "%",
            "<", ">", "^", "&", "*", "(", ")", "-",
            "=", "+", "_", "?", ":", ";", "\"", "'",
            ",", ".", "{", "}", "|", "[", "]", "/", "\\"
        )
        for (symbol in whitelistSymbols) {
            // 영문(abc) + 숫자(1) + 화이트리스트 특수문자 + 영문(d) = 6자 → isPasswordValidate 최소 길이 충족
            val password = "abc1${symbol}d"
            assertTrue(
                "Symbol '$symbol' should match CONTAIN_SYMBOL_REGEX",
                PasswordUtil.isContainSymbol(password)
            )
            assertTrue(
                "Symbol '$symbol' should pass isPasswordValidate",
                PasswordUtil.isPasswordValidate(password)
            )
        }
    }

    // 잔존 버그 회귀 테스트
    @Test
    fun `화이트리스트 특수문자와 공백이 함께 있으면 isPasswordValidate는 false를 반환한다`() {
        // 수정 전 .{6,18}은 공백을 허용해 true → 수정 후 false
        assertFalse(PasswordUtil.isPasswordValidate("abcde1! "))
    }

    @Test
    fun `화이트리스트 특수문자와 이모지가 함께 있으면 isPasswordValidate는 false를 반환한다`() {
        // 수정 전 .{6,18}은 이모지 서로게이트 페어를 허용해 true → 수정 후 false
        assertFalse(PasswordUtil.isPasswordValidate("abc1!😀"))
    }
}
