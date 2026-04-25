package `in`.koreatech.koin.feature.dining.ui.diningdetail.scroll

import androidx.compose.foundation.ScrollState
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.unit.Velocity
import `in`.koreatech.koin.core.nestedscroll.KoinNestedScrollConnection
import `in`.koreatech.koin.core.nestedscroll.KoinNestedScrollHeaderState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

class DiningNestedScrollConnection(
    private val state: KoinNestedScrollHeaderState,
    private val scope: CoroutineScope,
    private val currentScrollState: () -> ScrollState
) : KoinNestedScrollConnection(state, scope) {

    override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
        return if (available.y > 0) { // 스크롤 업
            val scrollValue = currentScrollState().value.toFloat()
            if (scrollValue <= available.y) {
                // 잔여 delta 계산 및 헤더 확장
                val remainingDelta = available.y - scrollValue
                val collapsedOffset = -(state.headerExpandedHeightPx - state.headerCollapsedHeightPx)
                val newOffset = (state.headerOffsetPx + remainingDelta).coerceIn(collapsedOffset, 0f)
                val consumed = newOffset - state.headerOffsetPx
                if (consumed != 0f) {
                    scope.launch { state.snapOffset(newOffset) }
                    Offset(0f, consumed)
                } else Offset.Zero
            } else {
                Offset.Zero // 아직 top 미도달
            }
        } else { // 스크롤 다운
            super.onPreScroll(available, source)
        }
    }

    override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource) = Offset.Zero

    override suspend fun onPostFling(consumed: Velocity, available: Velocity): Velocity = Velocity.Zero
}
