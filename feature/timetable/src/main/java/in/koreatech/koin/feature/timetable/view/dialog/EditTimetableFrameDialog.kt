package `in`.koreatech.koin.feature.timetable.view.dialog

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.BasicAlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import `in`.koreatech.koin.core.designsystem.component.button.FilledButton
import `in`.koreatech.koin.core.designsystem.component.button.FilledButtonColors
import `in`.koreatech.koin.core.designsystem.component.button.OutlinedBoxButton
import `in`.koreatech.koin.core.designsystem.component.button.OutlinedBoxButtonColors
import `in`.koreatech.koin.core.designsystem.theme.KoinTheme
import `in`.koreatech.koin.domain.model.timetable.response.TimetableFrame
import `in`.koreatech.koin.feature.timetable.R
import `in`.koreatech.koin.feature.timetable.component.FilledButtonType
import `in`.koreatech.koin.feature.timetable.component.FilledTextButton
import `in`.koreatech.koin.feature.timetable.component.HighlightedText
import `in`.koreatech.koin.feature.timetable.component.TextCheckbox

@Composable
fun EditTimetableFrameDialog(
    timetableFrameState: TimetableFrame?,
    onDismiss: () -> Unit,
    onConfirmEdit: (TimetableFrame) -> Unit,
    onDeleteFrame: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isMain by rememberSaveable(timetableFrameState?.id) { mutableStateOf(timetableFrameState?.isMain ?: false) }
    var timetableName by rememberSaveable(timetableFrameState?.id) { mutableStateOf(timetableFrameState?.timetableName ?: "") }
    var showingDeleteDialog by rememberSaveable(timetableFrameState?.id) { mutableStateOf(false) }

    // TODO:: 최대 길이에 관련된 명세 추가되면 수정
    val maxTimetableFrameNameLength = remember { 200 }

    EditTimetableFrameDialog(
        modifier = modifier,
        timetableName = timetableName,
        isMain = isMain,
        isCheckboxEnabled = timetableFrameState?.let { !it.isMain } ?: true,
        onDismiss = onDismiss,
        onConfirm = {
            timetableFrameState?.let {
                onConfirmEdit(
                    it.copy(
                        timetableName = timetableName,
                        isMain = isMain
                    )
                )
            }
        },
        onClickDelete = { showingDeleteDialog = true },
        onValueChanged = {
            // 최대 길이 제한
            if (it.length <= maxTimetableFrameNameLength) {
                timetableName = it
            }
        },
        onCheckChanged = {
            isMain = it
        }
    )

    if (showingDeleteDialog) {
        DeleteTimetableFrameDialog(
            timetableName = timetableFrameState?.timetableName ?: "",
            onDismiss = { showingDeleteDialog = false },
            onConfirm = {
                showingDeleteDialog = false
                timetableFrameState?.let {
                    onDeleteFrame()
                }
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditTimetableFrameDialog(
    timetableName: String,
    isMain: Boolean,
    isCheckboxEnabled: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
    onClickDelete: () -> Unit,
    onValueChanged: (String) -> Unit,
    onCheckChanged: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    BasicAlertDialog(
        modifier = modifier,
        onDismissRequest = onDismiss
    ) {
        Surface(
            modifier = Modifier
                .clickable(
                    onClick = {},
                    indication = null,
                    interactionSource = remember { MutableInteractionSource() },
                    role = null,
                    onClickLabel = null
                )
                .semantics { },
            shape = KoinTheme.shapes.extraSmall,
            color = KoinTheme.colors.neutral0
        ) {
            Column(
                modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Row(
                    modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(top = 16.dp),
                    horizontalArrangement = Arrangement.End
                ) {
                    FilledTextButton(
                        modifier =
                        Modifier
                            .heightIn(min = 48.dp),
                        text = stringResource(id = R.string.edit_titletable_frame_delete),
                        textStyle = KoinTheme.typography.medium14,
                        buttonStyle = FilledButtonType.Danger,
                        onClick = onClickDelete
                    )
                }
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = stringResource(id = R.string.edit_titletable_frame_title),
                    style = KoinTheme.typography.bold16
                )
                Spacer(modifier = Modifier.height(10.dp))
                // TODO:: 높이 수정 필요
                val textFieldShape = KoinTheme.shapes.extraSmall
                TextField(
                    modifier =
                    Modifier
                        .fillMaxWidth()
                        .border(
                            border =
                            BorderStroke(
                                width = 1.dp,
                                color = KoinTheme.colors.neutral300
                            ),
                            shape = textFieldShape
                        ),
                    shape = textFieldShape,
                    value = timetableName,
                    textStyle = KoinTheme.typography.regular14,
                    colors =
                    TextFieldDefaults.colors(
                        unfocusedContainerColor = KoinTheme.colors.neutral100, // 배경색 (클릭 X)
                        focusedContainerColor = KoinTheme.colors.neutral100, // 배경색 (클릭 O)
                        unfocusedIndicatorColor = Color.Transparent, // 밑줄색 (클릭 X)
                        focusedIndicatorColor = Color.Transparent, // 밑줄색 (클릭 O)
                        unfocusedTextColor = KoinTheme.colors.neutral500, // 클릭 X 시 텍스트 색
                        focusedTextColor = KoinTheme.colors.neutral500, // 클릭 O 시 텍스트 색
                        cursorColor = KoinTheme.colors.primary500 // 클릭 시, 커서색
                    ),
                    singleLine = true,
                    onValueChange = onValueChanged
                )
                Spacer(modifier = Modifier.height(10.dp))
                TextCheckbox(
                    modifier = Modifier.align(Alignment.Start),
                    text = stringResource(id = R.string.edit_titletable_frame_main),
                    textStyle = KoinTheme.typography.medium14,
                    isChecked = isMain,
                    enabled = isCheckboxEnabled,
                    onCheckChanged = onCheckChanged
                )
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedBoxButton(
                        modifier =
                        Modifier
                            .heightIn(min = 48.dp)
                            .weight(1.0F),
                        text = stringResource(id = R.string.common_cancellation),
                        onClick = onDismiss,
                        colors = OutlinedBoxButtonColors.Neutral
                    )
                    FilledTextButton(
                        modifier =
                        Modifier
                            .heightIn(min = 48.dp)
                            .weight(1.0F),
                        text = stringResource(id = R.string.common_save),
                        onClick = onConfirm
                    )
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DeleteTimetableFrameDialog(
    timetableName: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
    modifier: Modifier = Modifier
) {
    val baseTitle = stringArrayResource(id = R.array.delete_titletable_frame_title)
    val title = remember(timetableName, baseTitle.contentHashCode()) {
        baseTitle.mapIndexed { index, text ->
            if (index == 0) text.format(timetableName) else text
        }.toTypedArray()
    }

    BasicAlertDialog(
        onDismissRequest = onDismiss,
        modifier = modifier
    ) {
        Surface(
            modifier = Modifier
                .clickable(
                    onClick = {},
                    indication = null,
                    interactionSource = remember { MutableInteractionSource() },
                    role = null,
                    onClickLabel = null
                )
                .semantics { },
            shape = KoinTheme.shapes.extraSmall,
            color = KoinTheme.colors.neutral0
        ) {
            Column(
                modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(
                        horizontal = 32.dp,
                        vertical = 24.dp
                    ),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                HighlightedText(
                    texts = title,
                    highlightIndices = listOf(1),
                    defaultStyle =
                    KoinTheme.typography.medium16.copy(
                        color = KoinTheme.colors.neutral600
                    ),
                    highlightStyle =
                    KoinTheme.typography.bold16.copy(
                        color = KoinTheme.colors.danger700
                    )
                )
                Spacer(modifier = Modifier.height(24.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedBoxButton(
                        modifier =
                        Modifier
                            .heightIn(min = 48.dp)
                            .weight(1.0F),
                        text = stringResource(id = R.string.common_cancellation),
                        onClick = onDismiss,
                        colors = OutlinedBoxButtonColors.Neutral
                    )
                    FilledButton(
                        modifier =
                        Modifier
                            .heightIn(min = 48.dp)
                            .weight(1.0F),
                        text = stringResource(id = R.string.delete_titletable_frame_confirmation),
                        onClick = onConfirm,
                        colors = FilledButtonColors.Danger
                    )
                }
            }
        }
    }
}

@Preview
@Composable
private fun EditTimetableFrameDialogPreview() {
    KoinTheme {
        EditTimetableFrameDialog(
            timetableFrameState =
            TimetableFrame(
                id = 1,
                timetableName = "시간표1",
                isMain = true
            ),
            onDismiss = {},
            onConfirmEdit = {},
            onDeleteFrame = {}
        )
    }
}

@Preview
@Composable
private fun DeleteTimetableFrameDialogPreview() {
    KoinTheme {
        DeleteTimetableFrameDialog(
            timetableName = "시간표1",
            onDismiss = {},
            onConfirm = {}
        )
    }
}
