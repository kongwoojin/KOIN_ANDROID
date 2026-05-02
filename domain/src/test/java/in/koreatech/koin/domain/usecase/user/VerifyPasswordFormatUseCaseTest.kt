package `in`.koreatech.koin.domain.usecase.user

import `in`.koreatech.koin.domain.util.regex.PasswordUtil
import junit.framework.TestCase.assertFalse
import junit.framework.TestCase.assertTrue
import org.junit.Before
import org.junit.Test

class VerifyPasswordFormatUseCaseTest {
    private lateinit var useCase: VerifyPasswordFormatUseCase
    private lateinit var passwordUtil: PasswordUtil

    @Before
    fun setUp() {
        useCase = VerifyPasswordFormatUseCase()
        passwordUtil = PasswordUtil()
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
        assertFalse(passwordUtil.isPasswordValidate(password))
    }

    @Test
    fun `화이트리스트 특수문자는 isIncludeSymbol과 isPasswordValidate 양쪽에서 모두 일관되게 특수문자로 인정된다`() {
        val password = "abcde1!"
        val result = useCase.invoke(password)
        // UI 피드백: 화이트리스트 문자(!)는 특수문자로 인정
        assertTrue(result.isIncludeSymbol)
        // 실제 유효성: 영문 + 숫자 + 화이트리스트 특수문자 + 길이 충족 → 통과
        assertTrue(passwordUtil.isPasswordValidate(password))
    }
}
