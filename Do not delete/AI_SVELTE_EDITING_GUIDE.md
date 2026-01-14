# AI Agent Guide: Svelte File Editing Best Practices

## Purpose
This guide helps AI agents avoid common structural errors when editing Svelte component files, particularly HTML div closing tag mistakes.

---

## Critical Rules for Svelte Component Editing

### 1. **ALWAYS Verify HTML Structure Before Making Changes**

Before modifying any Svelte component:
- Read a large enough section to understand the complete structure
- Identify all opening tags: `<div class="...">`, `<div>`, `{#if}`, `{#each}`
- Count their corresponding closing tags: `</div>`, `{/if}`, `{/each}`
- Map out the nesting hierarchy mentally or in comments

### 2. **When Removing or Adding Sections**

**DO:**
- Count opening tags in the section you're removing/adding
- Count closing tags in the section you're removing/adding
- Verify the count matches EXACTLY
- Read 10-20 lines before AND after the target section for context

**DON'T:**
- Remove a section without verifying tag balance
- Add content without checking what divs need to close it
- Trust that the structure is correct without verification
- Make assumptions about indentation indicating structure

### 3. **Verification Checklist for Every Edit**

After making ANY edit to HTML/Svelte template:

```
□ Count all opening <div> tags in my edit
□ Count all closing </div> tags in my edit
□ Verify the counts match
□ Check that {#if} has matching {/if}
□ Check that {#each} has matching {/each}
□ Check that {:else} is properly placed within {#if}
□ Read the file section again to verify structure
□ Check for syntax errors using get_errors tool
```

### 4. **Common Mistake Patterns to Avoid**

#### Mistake #1: Removing Loop Without Adjusting Close Tags
```svelte
<!-- WRONG -->
{#each items as item}
  <div>content</div>
{/each}
<!-- If you remove the loop, you might accidentally remove closing tags too -->

<!-- CORRECT -->
<!-- When removing loop, keep the same number of divs for content -->
<div>content</div>
```

#### Mistake #2: Not Counting Nested Structures
```svelte
<!-- Structure has 4 opening divs but you only count 3 -->
<div class="outer">          <!-- 1 -->
  <div class="middle">       <!-- 2 -->
    {#if condition}
      <div class="inner">    <!-- 3 -->
        <div class="content"><!-- 4 -->
        </div>               <!-- closes 4 -->
      </div>                 <!-- closes 3 -->
    {/if}
  </div>                     <!-- closes 2 -->
</div>                       <!-- closes 1 -->
```

#### Mistake #3: Forgetting Parent Container Closing Tags
```svelte
<!-- WRONG: Removed loop but forgot parent div needs closing -->
<div class="container">
  <!-- removed: {#each items} -->
  <!-- removed: {/each} -->
</div>
<!-- Missing: </div> for container -->

<!-- CORRECT: Keep parent closing tag -->
<div class="container">
  <!-- removed: {#each items} -->
  <!-- removed: {/each} -->
</div>
</div>  <!-- This was needed! -->
```

---

## Step-by-Step Process for Safe Edits

### When REMOVING a section:

1. **Read 20 lines before the target**
2. **Read the entire target section**
3. **Read 20 lines after the target**
4. **Count opening tags** in what you'll remove
5. **Count closing tags** in what you'll remove
6. **If counts don't match**, expand your selection until they do
7. **Make the edit**
8. **Run `get_errors` tool immediately after**
9. **If error exists, read the error area and 20 lines around it**
10. **Fix by re-counting the structure**

### When ADDING a section:

1. **Identify where the new section will be inserted**
2. **Read 20 lines before and after the insertion point**
3. **Understand what div/container the new content belongs in**
4. **Write the complete new section with all opening and closing tags**
5. **Count tags in your new section before inserting**
6. **Make the edit**
7. **Run `get_errors` tool**
8. **Verify structure is correct**

### When MODIFYING a section:

1. **Use the same removal + addition process above**
2. **Never do partial edits that break tag balance**
3. **Always replace complete balanced structures**

---

## Tools to Use for Verification

### After Every Edit:
```typescript
// ALWAYS run this after editing Svelte files
get_errors({ filePaths: ["path/to/file.svelte"] })
```

### If Unsure About Structure:
```typescript
// Read more context to understand nesting
read_file({ 
  filePath: "path/to/file.svelte",
  startLine: targetLine - 30,
  endLine: targetLine + 30
})
```

### To Find Tag Pairs:
```typescript
// Search for opening tags
grep_search({ 
  query: '<div class="specific-class"',
  isRegexp: false,
  includePattern: "**/*.svelte"
})
```

---

## Special Considerations for Svelte

### 1. Svelte Control Flow Blocks
- `{#if condition}...{:else}...{/if}` - must be balanced
- `{#each items as item}...{/each}` - must be balanced
- `{#await promise}...{:then}...{:catch}...{/await}` - must be balanced
- These are NOT divs but must be counted as structural elements

### 2. Component Tags
- `<ComponentName>` requires `</ComponentName>`
- Self-closing tags: `<ComponentName />`
- Count these like divs

### 3. Void Elements (No Closing Tag Needed)
- `<input />`, `<br />`, `<img />`, `<hr />`
- Do NOT count these as needing closing tags

---

## Emergency Recovery Process

If you've created an unclosed tag error:

1. **Read the error message for the line number**
2. **Read that line and 50 lines after it**
3. **Find the tag mentioned in the error**
4. **Count ALL closing tags from that point to the end of template**
5. **Count ALL opening tags from that point backwards to beginning**
6. **The difference tells you how many tags to add/remove**
7. **Look for comments like "End of section" to find logical endpoints**
8. **Add/remove closing tags at the appropriate nesting level**
9. **Re-run get_errors**
10. **Repeat until clean**

---

## Template for Safe Multi-Step Edits

```markdown
## Plan:
1. Read current structure (lines X-Y)
2. Identify tags to modify:
   - Opening: [list them]
   - Closing: [list them]
3. Verify counts match
4. Make edit
5. Run get_errors
6. If error, read error context
7. Fix and verify again

## Execution:
[Perform steps with verification at each stage]
```

---

## Key Reminders

✅ **READ MORE CONTEXT** - 20+ lines before and after
✅ **COUNT TAGS** - Every opening must have a closing
✅ **VERIFY IMMEDIATELY** - Use get_errors after every edit
✅ **UNDERSTAND STRUCTURE** - Don't guess at nesting
✅ **EXPAND SELECTION** - If unsure, read more lines

❌ **Don't make quick edits without counting**
❌ **Don't assume indentation shows structure**
❌ **Don't skip verification steps**
❌ **Don't remove content without understanding context**

---

## Success Metrics

A successful edit means:
- ✅ No compilation errors
- ✅ All tags properly balanced
- ✅ Logical structure maintained
- ✅ No orphaned closing tags
- ✅ No unclosed opening tags

---

## File-Specific Notes

### For EmployeeFiles.svelte:
- Main container: `<div class="employee-files-container">`
- Grid wrapper: `<div class="cards-wrapper">`
- Two main cards: Card 1 (Search), Card 2 (Files)
- Card 2 contains: `<div class="file-cards-grid">` with multiple file cards
- Each card has nested structure: card > card-content > content
- Use comments to mark section boundaries
- File cards grid ends with `<!-- End of file cards grid -->` comment

---

## Last Resort

If you're stuck in a loop of errors:
1. **Stop editing**
2. **Read the ENTIRE template section** (all 500+ lines if needed)
3. **Create a mental map of the structure**
4. **Start from the innermost tags and work outward**
5. **Verify each level before moving to the next**
