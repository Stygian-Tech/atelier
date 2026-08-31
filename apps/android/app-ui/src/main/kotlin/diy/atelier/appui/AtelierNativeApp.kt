package diy.atelier.appui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import diy.atelier.core.AppProduct
import diy.atelier.core.OfflineStatus
import diy.atelier.core.PersistencePhase
import diy.atelier.core.WorkspaceItem
import diy.atelier.core.WorkspaceSection
import diy.atelier.editor.NativeMarkdownEditor
import diy.atelier.persistence.LocalWorkspaceRepository
import diy.atelier.persistence.MockLocalWorkspaceRepository
import java.time.Instant

@Composable
fun AtelierNativeApp(
    product: AppProduct,
    repository: LocalWorkspaceRepository? = null,
) {
    val localRepository = repository ?: remember(product) { MockLocalWorkspaceRepository(product) }
    var sectionId by rememberSaveable(product) {
        mutableStateOf(product.sections.firstOrNull()?.id ?: "inbox")
    }
    var workspaceItems by remember(product) { mutableStateOf(emptyList<WorkspaceItem>()) }
    var selectedItemId by rememberSaveable(product) { mutableStateOf<String?>(null) }

    LaunchedEffect(sectionId, localRepository) {
        workspaceItems = localRepository.items(sectionId)
        if (workspaceItems.none { it.id == selectedItemId }) {
            selectedItemId = workspaceItems.firstOrNull()?.id
        }
    }

    val selectSection: (String) -> Unit = { sectionId = it }
    val createDraft = {
        val draft = WorkspaceItem(
            title = "Untitled",
            summary = "Local draft",
            markdown = "# Untitled\n",
            sectionId = sectionId,
        )
        localRepository.save(draft)
        workspaceItems = localRepository.items(sectionId)
        selectedItemId = draft.id
    }

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val expanded = maxWidth >= 840.dp
        if (expanded) {
            ExpandedWorkspace(
                product = product,
                sections = product.sections,
                selectedSectionId = sectionId,
                onSelectSection = selectSection,
                items = workspaceItems,
                selectedItemId = selectedItemId,
                onSelectItem = { selectedItemId = it },
                repository = localRepository,
                onItemsChanged = { workspaceItems = localRepository.items(sectionId) },
                onCreateDraft = createDraft,
            )
        } else {
            CompactWorkspace(
                product = product,
                sections = product.sections,
                selectedSectionId = sectionId,
                onSelectSection = selectSection,
                items = workspaceItems,
                selectedItemId = selectedItemId,
                onSelectItem = { selectedItemId = it },
                repository = localRepository,
                onItemsChanged = { workspaceItems = localRepository.items(sectionId) },
                onCreateDraft = createDraft,
            )
        }
    }
}

@Composable
private fun ExpandedWorkspace(
    product: AppProduct,
    sections: List<WorkspaceSection>,
    selectedSectionId: String,
    onSelectSection: (String) -> Unit,
    items: List<WorkspaceItem>,
    selectedItemId: String?,
    onSelectItem: (String) -> Unit,
    repository: LocalWorkspaceRepository,
    onItemsChanged: () -> Unit,
    onCreateDraft: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxSize()) {
        ProductTopBar(product = product, status = OfflineStatus.LocalOnly)
        Row(modifier = Modifier.fillMaxSize()) {
            NavigationRail {
                sections.forEach { section ->
                    NavigationRailItem(
                        selected = section.id == selectedSectionId,
                        onClick = { onSelectSection(section.id) },
                        icon = { Text(section.shortLabel) },
                        label = { Text(section.title) },
                        alwaysShowLabel = true,
                    )
                }
            }
            Divider(modifier = Modifier.fillMaxHeight().width(1.dp))
            WorkspaceList(
                items = items,
                selectedItemId = selectedItemId,
                onSelectItem = onSelectItem,
                onCreateDraft = onCreateDraft,
                modifier = Modifier.width(340.dp).fillMaxHeight(),
            )
            Divider(modifier = Modifier.fillMaxHeight().width(1.dp))
            WorkspaceEditor(
                selectedItem = items.firstOrNull { it.id == selectedItemId },
                repository = repository,
                onSaved = onItemsChanged,
                modifier = Modifier.weight(1f).fillMaxHeight(),
            )
        }
    }
}

@Composable
private fun CompactWorkspace(
    product: AppProduct,
    sections: List<WorkspaceSection>,
    selectedSectionId: String,
    onSelectSection: (String) -> Unit,
    items: List<WorkspaceItem>,
    selectedItemId: String?,
    onSelectItem: (String) -> Unit,
    repository: LocalWorkspaceRepository,
    onItemsChanged: () -> Unit,
    onCreateDraft: () -> Unit,
) {
    Scaffold(
        topBar = { ProductTopBar(product = product, status = OfflineStatus.LocalOnly) },
        bottomBar = {
            NavigationBar {
                sections.forEach { section ->
                    NavigationBarItem(
                        selected = section.id == selectedSectionId,
                        onClick = { onSelectSection(section.id) },
                        icon = { Text(section.shortLabel) },
                        label = { Text(section.title, maxLines = 1) },
                    )
                }
            }
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                PublicPdsDisclosure(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
            }
            item {
                Button(
                    onClick = onCreateDraft,
                    modifier = Modifier.padding(horizontal = 16.dp),
                ) {
                    Text(stringResource(R.string.new_local_draft))
                }
            }
            items(items = items, key = WorkspaceItem::id) { item ->
                WorkspaceItemButton(
                    item = item,
                    selected = item.id == selectedItemId,
                    onClick = { onSelectItem(item.id) },
                    modifier = Modifier.padding(horizontal = 8.dp),
                )
            }
            item {
                WorkspaceEditor(
                    selectedItem = items.firstOrNull { it.id == selectedItemId },
                    repository = repository,
                    onSaved = onItemsChanged,
                    modifier = Modifier.fillMaxWidth().height(420.dp).padding(16.dp),
                )
            }
        }
    }
}

@Composable
private fun ProductTopBar(product: AppProduct, status: OfflineStatus) {
    Surface(shadowElevation = 2.dp) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = product.displayName,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.semantics { heading() },
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = status.label(),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

@Composable
private fun WorkspaceList(
    items: List<WorkspaceItem>,
    selectedItemId: String?,
    onSelectItem: (String) -> Unit,
    onCreateDraft: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.padding(12.dp)) {
        PublicPdsDisclosure()
        Spacer(modifier = Modifier.height(12.dp))
        Button(onClick = onCreateDraft, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.new_local_draft))
        }
        Spacer(modifier = Modifier.height(8.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            items(items = items, key = WorkspaceItem::id) { item ->
                WorkspaceItemButton(
                    item = item,
                    selected = item.id == selectedItemId,
                    onClick = { onSelectItem(item.id) },
                )
            }
        }
    }
}

@Composable
private fun WorkspaceItemButton(
    item: WorkspaceItem,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    TextButton(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = item.title,
                style = MaterialTheme.typography.titleMedium,
                color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = item.summary,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun WorkspaceEditor(
    selectedItem: WorkspaceItem?,
    repository: LocalWorkspaceRepository,
    onSaved: () -> Unit,
    modifier: Modifier = Modifier,
) {
    if (selectedItem == null) {
        Column(
            modifier = modifier.padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(stringResource(R.string.select_an_item), style = MaterialTheme.typography.titleMedium)
        }
        return
    }

    var markdown by rememberSaveable(selectedItem.id) { mutableStateOf(selectedItem.markdown) }
    Column(modifier = modifier.padding(16.dp)) {
        Text(
            text = selectedItem.title,
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.semantics { heading() },
        )
        Spacer(modifier = Modifier.height(12.dp))
        NativeMarkdownEditor(
            value = markdown,
            onValueChange = { markdown = it },
            modifier = Modifier.weight(1f),
        )
        Spacer(modifier = Modifier.height(12.dp))
        Button(
            onClick = {
                repository.save(
                    selectedItem.copy(markdown = markdown, updatedAt = Instant.now()),
                )
                onSaved()
            },
            enabled = markdown != selectedItem.markdown,
            modifier = Modifier.align(Alignment.End),
        ) {
            Text(stringResource(R.string.save_locally))
        }
    }
}

@Composable
private fun PublicPdsDisclosure(modifier: Modifier = Modifier) {
    Card(
        modifier = modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = stringResource(R.string.standard_pds_records_are_public),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = stringResource(R.string.public_pds_explanation),
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Composable
private fun OfflineStatus.label(): String = when (phase) {
    PersistencePhase.LOCAL_ONLY -> stringResource(R.string.local_only)
    PersistencePhase.QUEUED -> stringResource(R.string.waiting_to_sync)
    PersistencePhase.SYNCING -> stringResource(R.string.syncing)
    PersistencePhase.DURABLE -> stringResource(R.string.durably_saved)
    PersistencePhase.NEEDS_ATTENTION -> stringResource(R.string.sync_needs_attention)
}
