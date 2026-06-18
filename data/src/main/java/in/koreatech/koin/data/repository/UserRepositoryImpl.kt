package `in`.koreatech.koin.data.repository

import `in`.koreatech.koin.data.mapper.safeApiCall
import `in`.koreatech.koin.data.mapper.toCodeCount
import `in`.koreatech.koin.data.mapper.toUser
import `in`.koreatech.koin.data.mapper.toUserRequest
import `in`.koreatech.koin.data.request.owner.OwnerLoginRequest
import `in`.koreatech.koin.data.request.user.ABTestRequest
import `in`.koreatech.koin.data.request.user.EmailSendRequest
import `in`.koreatech.koin.data.request.user.EmailVerifyRequest
import `in`.koreatech.koin.data.request.user.IdRequest
import `in`.koreatech.koin.data.request.user.LoginRequest
import `in`.koreatech.koin.data.request.user.PasswordRequest
import `in`.koreatech.koin.data.request.user.SmsSendRequest
import `in`.koreatech.koin.data.request.user.SmsVerifyRequest
import `in`.koreatech.koin.data.source.local.TokenLocalDataSource
import `in`.koreatech.koin.data.source.local.UserLocalDataSource
import `in`.koreatech.koin.data.source.remote.UserRemoteDataSource
import `in`.koreatech.koin.data.util.mapHttpFailure
import `in`.koreatech.koin.domain.error.user.KoinUserException
import `in`.koreatech.koin.domain.model.user.ABTest
import `in`.koreatech.koin.domain.model.user.AuthToken
import `in`.koreatech.koin.domain.model.user.CodeCount
import `in`.koreatech.koin.domain.model.user.User
import `in`.koreatech.koin.domain.model.user.UserType
import `in`.koreatech.koin.domain.repository.UserRepository
import javax.inject.Inject
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.runBlocking
import retrofit2.HttpException

class UserRepositoryImpl @Inject constructor(
    private val userRemoteDataSource: UserRemoteDataSource,
    private val tokenLocalDataSource: TokenLocalDataSource,
    private val userLocalDataSource: UserLocalDataSource
) : UserRepository {
    override suspend fun getToken(
        loginId: String,
        hashedPassword: String
    ): AuthToken {
        val authResponse =
            userRemoteDataSource.getToken(
                LoginRequest(loginId, hashedPassword)
            )

        return AuthToken(authResponse.token, authResponse.refreshToken, authResponse.userType)
    }

    override suspend fun getOwnerToken(
        phoneNumber: String,
        hashedPassword: String
    ): AuthToken {
        val authResponse =
            userRemoteDataSource.getOwnerToken(
                OwnerLoginRequest(phoneNumber, hashedPassword)
            )

        return AuthToken(authResponse.token, authResponse.refreshToken)
    }

    override fun ownerTokenIsValid(): Boolean {
        return runBlocking {
            try {
                userRemoteDataSource.ownerTokenIsValid()
                true
            } catch (e: HttpException) {
                if (e.code() == 401) {
                    false
                } else {
                    throw e
                }
            }
        }
    }

    override suspend fun fetchStudentUserInfo() {
        userRemoteDataSource.getStudentUserInfo().toUser().also {
            userLocalDataSource.updateUserInfo(it)
        }
    }

    override suspend fun fetchGeneralUserInfo() {
        userRemoteDataSource.getGeneralUserInfo().toUser().also {
            userLocalDataSource.updateUserInfo(it)
        }
    }

    override suspend fun getUserInfo(): User {
        return when (userLocalDataSource.user.first()) {
            is User.Student -> userRemoteDataSource.getStudentUserInfo().toUser().also {
                userLocalDataSource.updateUserInfo(it)
            }

            is User.General -> userRemoteDataSource.getGeneralUserInfo().toUser().also {
                userLocalDataSource.updateUserInfo(it)
            }

            is User.Anonymous -> User.Anonymous

            null -> {
                when (userLocalDataSource.userType.first()) {
                    UserType.STUDENT,
                    UserType.COUNCIL -> userRemoteDataSource.getStudentUserInfo().toUser().also {
                        userLocalDataSource.updateUserInfo(it)
                    }

                    UserType.GENERAL -> userRemoteDataSource.getGeneralUserInfo().toUser().also {
                        userLocalDataSource.updateUserInfo(it)
                    }

                    else -> User.Anonymous
                }
            }
        }
    }

    override fun getUserInfoFlow(): Flow<User> {
        return userLocalDataSource.user.map { it ?: getUserInfo() }
    }

    override suspend fun requestPasswordResetEmail(email: String) {
        userRemoteDataSource.sendPasswordResetEmail(IdRequest(email))
    }

    override suspend fun deleteUser() {
        try {
            userRemoteDataSource.deleteUser()
            userLocalDataSource.updateUserInfo(User.Anonymous)
            userLocalDataSource.updateIsLogin(false)
            tokenLocalDataSource.removeAccessToken()
            tokenLocalDataSource.removeRefreshToken()
        } catch (e: HttpException) {
            throw e
        }
    }

    override suspend fun isUserEmailDuplicated(email: String): Boolean {
        return try {
            userRemoteDataSource.checkEmail(email)
            false
        } catch (e: HttpException) {
            if (e.code() == 409) {
                true
            } else {
                throw e
            }
        }
    }

    override suspend fun updateUser(user: User): Result<Unit> = safeApiCall {
        when (user) {
            User.Anonymous -> throw IllegalAccessException("Updating anonymous user is not supported")
            is User.Student -> {
                userRemoteDataSource.updateStudentUser(user.toUserRequest())
                userLocalDataSource.updateUserInfo(user)
            }

            is User.General -> {
                userRemoteDataSource.updateGeneralUser(user.toUserRequest())
                userLocalDataSource.updateUserInfo(user)
            }
        }
    }.onSuccess {
        userLocalDataSource.updateUserInfo(user)
    }.mapHttpFailure {
        on(400) throws KoinUserException.DataInvalidException()
        on(401) throws KoinUserException.UnauthorizedException()
        on(404) throws KoinUserException.UserNotFoundException()
        on(409) throws KoinUserException.NicknameOrEmailConflictException()
    }

    override suspend fun deleteDeviceToken() {
        tokenLocalDataSource.removeDeviceToken()
        userRemoteDataSource.deleteDeviceToken()
    }

    override suspend fun verifyPassword(hashedPassword: String) {
        userRemoteDataSource.verifyPassword(PasswordRequest(hashedPassword))
    }

    override suspend fun updateABTestToken() {
        userRemoteDataSource.updateABTestToken().accessHistoryId.also {
            tokenLocalDataSource.saveAccessHistoryId(it)
        }
    }

    override suspend fun postABTestAssign(title: String): ABTest {
        val (variableName, accessHistoryId) = userRemoteDataSource.postABTestAssign(ABTestRequest(title))

        safeApiCall {
            userLocalDataSource.insertCachedABTest(title, accessHistoryId, variableName)
        }

        return ABTest(variableName, accessHistoryId)
    }

    override suspend fun getCachedABTest(title: String): ABTest {
        val accessHistoryId = tokenLocalDataSource.getAccessHistoryId() ?: throw IllegalStateException("Access history id is not found")
        return userLocalDataSource.getCachedABTest(title, accessHistoryId)
    }

    override suspend fun updateUserPassword(
        hashedPassword: String
    ): Result<Unit> {
        return safeApiCall {
            userRemoteDataSource.updateUserPassword(hashedPassword) // TODO: Handle error after error code PR is completed.
        }
    }

    override suspend fun requestSmsVerification(phoneNumber: String): Result<CodeCount> {
        return safeApiCall {
            userRemoteDataSource.sendSMS(SmsSendRequest(phoneNumber)).toCodeCount()
        }.mapHttpFailure {
            on(400) throws KoinUserException.PhoneNumberInvalidException()
            on(429) throws KoinUserException.VerificationCodeRequestCountExceededException()
        }
    }

    override suspend fun requestEmailVerification(email: String): Result<CodeCount> {
        return safeApiCall {
            userRemoteDataSource.sendEmail(EmailSendRequest(email)).toCodeCount()
        }.mapHttpFailure {
            on(400) throws KoinUserException.EmailInvalidException()
            on(429) throws KoinUserException.VerificationCodeRequestCountExceededException()
        }
    }

    override suspend fun verifyCertificationCode(phoneNumber: String, verificationCode: String): Result<Unit> {
        return safeApiCall {
            userRemoteDataSource.verifyCode(
                SmsVerifyRequest(
                    phoneNumber = phoneNumber,
                    verificationCode = verificationCode
                )
            )
        }.mapHttpFailure {
            on(400) throws KoinUserException.VerificationCodeInvalidException()
            on(404) throws KoinUserException.VerificationCodeExpiredException()
        }
    }

    override suspend fun verifyEmailCode(email: String, verificationCode: String): Result<Unit> {
        return safeApiCall {
            userRemoteDataSource.verifyEmailCode(
                EmailVerifyRequest(
                    email = email,
                    verificationCode = verificationCode
                )
            )
        }.mapHttpFailure {
            on(400) throws KoinUserException.VerificationCodeInvalidException()
            on(404) throws KoinUserException.VerificationCodeExpiredException()
        }
    }

    override suspend fun checkIdExists(loginId: String): Result<Unit> {
        return safeApiCall {
            userRemoteDataSource.idExists(loginId)
        }.mapHttpFailure {
            on(400) throws KoinUserException.LoginIdInvalidException()
            on(404) throws KoinUserException.LoginIdNotFoundException()
        }
    }

    override suspend fun checkIdMatchEmail(loginId: String, email: String): Result<Unit> {
        return safeApiCall {
            userRemoteDataSource.idMatchEmail(loginId, email)
        }.mapHttpFailure {
            on(400) throws KoinUserException.LoginIdNotMatchEmailException()
            on(404) throws KoinUserException.LoginIdNotFoundException()
        }
    }

    override suspend fun checkIdMatchPhone(loginId: String, phone: String): Result<Unit> {
        return safeApiCall {
            userRemoteDataSource.idMatchPhone(
                loginId,
                phone
            )
        }.mapHttpFailure {
            on(400) throws KoinUserException.LoginIdNotMatchPhoneException()
            on(404) throws KoinUserException.LoginIdNotFoundException()
        }
    }

    override suspend fun resetPasswordByEmail(loginId: String, email: String, newPassword: String): Result<Unit> {
        return safeApiCall {
            userRemoteDataSource.resetPasswordByEmail(
                loginId,
                email,
                newPassword
            )
        }.mapHttpFailure {
            on(400) throws KoinUserException.LoginIdNotMatchEmailException()
            on(401) throws KoinUserException.UnauthorizedException()
            on(404) throws KoinUserException.LoginIdNotFoundException()
        }
    }

    override suspend fun resetPasswordBySms(loginId: String, phone: String, newPassword: String): Result<Unit> {
        return safeApiCall {
            userRemoteDataSource.resetPasswordBySms(loginId, phone, newPassword)
        }.mapHttpFailure {
            on(400) throws KoinUserException.LoginIdNotMatchPhoneException()
            on(401) throws KoinUserException.UnauthorizedException()
            on(404) throws KoinUserException.LoginIdNotFoundException()
        }
    }

    override suspend fun checkEmailExists(email: String): Result<Unit> {
        return safeApiCall {
            userRemoteDataSource.checkEmailExists(email)
        }.mapHttpFailure {
            on(400) throws KoinUserException.EmailInvalidException()
            on(404) throws KoinUserException.EmailNotFoundException()
        }
    }

    override suspend fun checkPhoneExists(phone: String): Result<Unit> {
        return safeApiCall {
            userRemoteDataSource.checkPhoneExists(phone)
        }.mapHttpFailure {
            on(400) throws KoinUserException.PhoneNumberInvalidException()
            on(404) throws KoinUserException.PhoneNumberNotFoundException()
        }
    }

    override suspend fun findLoginIdByEmail(email: String, verificationCode: String): Result<String> {
        return safeApiCall {
            userRemoteDataSource.findLoginIdByEmail(EmailVerifyRequest(email, verificationCode)).loginId
        }.mapHttpFailure {
            on(400) throws KoinUserException.EmailInvalidException()
            on(401) throws KoinUserException.UnauthorizedException()
            on(404) throws KoinUserException.EmailNotFoundException()
        }
    }

    override suspend fun findLoginIdBySms(phone: String, verificationCode: String): Result<String> {
        return safeApiCall {
            userRemoteDataSource.findLoginIdBySms(SmsVerifyRequest(phone, verificationCode)).loginId
        }.mapHttpFailure {
            on(400) throws KoinUserException.PhoneNumberInvalidException()
            on(401) throws KoinUserException.UnauthorizedException()
            on(404) throws KoinUserException.PhoneNumberNotFoundException()
        }
    }
}
