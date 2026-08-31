package diy.atelier.editor

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics

data class MarkdownDocument(
    val source: String = "",
    val revision: ULong = 0u,
)

object MarkdownEditorReducer {
    fun replaceSource(document: MarkdownDocument, source: String): MarkdownDocument =
        if (source == document.source) document
        else document.copy(source = source, revision = document.revision + 1u)
}

@Composable
fun NativeMarkdownEditor(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val editorDescription = stringResource(R.string.markdown_editor)
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier
            .fillMaxSize()
            .semantics { contentDescription = editorDescription },
        textStyle = MaterialTheme.typography.bodyLarge,
        label = { androidx.compose.material3.Text(stringResource(R.string.markdown)) },
        supportingText = {
            androidx.compose.material3.Text(stringResource(R.string.canonical_markdown_source))
        },
    )
}
