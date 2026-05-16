const fs = require('fs');
const path = require('path');

const dumpFile = 'D:/Aqura/supabase/migrations/20260515000000_current_schema.sql';
const outputDir = 'D:/Aqura/supabase/migrations/tables';

fs.mkdirSync(outputDir, { recursive: true });

const content = fs.readFileSync(dumpFile, 'utf8');

// Split by section headers: --\n-- Name: X; Type: Y; Schema: Z; Owner: W\n--\n
const sectionPattern = /\n--\n-- Name: ([^;]+); Type: ([^;]+); Schema: ([^;]+);[^\n]*\n--\n/g;

const matches = [];
let match;
while ((match = sectionPattern.exec(content)) !== null) {
  matches.push({
    start: match.index,
    headerEnd: match.index + match[0].length,
    name: match[1].trim(),
    type: match[2].trim(),
    schema: match[3].trim(),
  });
}

// Extract content for each section
const sections = matches.map((m, i) => {
  const nextStart = i + 1 < matches.length ? matches[i + 1].start : content.length;
  return {
    ...m,
    content: content.slice(m.headerEnd, nextStart).trim(),
  };
});

// Find all public tables
const tableMap = {};
sections
  .filter(s => s.type === 'TABLE' && s.schema === 'public')
  .forEach(s => {
    tableMap[s.name] = { tableName: s.name, items: [s] };
  });

// Longest names first to avoid partial matches (e.g. "orders" vs "orders_items")
const tableNames = Object.keys(tableMap).sort((a, b) => b.length - a.length);

// Associate related sections to their table
sections.forEach(s => {
  if (s.type === 'TABLE') return;
  if (s.schema !== 'public' && s.schema !== '-') return;

  let found = null;

  switch (s.type) {
    case 'SEQUENCE':
    case 'DEFAULT':
    case 'TRIGGER':
    case 'POLICY':
    case 'ROW SECURITY':
    case 'CONSTRAINT':
    case 'CHECK CONSTRAINT':
      // Name is "tablename [objectname]"
      found = tableNames.find(t => s.name === t || s.name.startsWith(t + ' '));
      break;

    case 'SEQUENCE OWNED BY': {
      const m = s.content.match(/OWNED BY public\.(\w+)\./);
      if (m) found = m[1];
      break;
    }

    case 'INDEX': {
      const m = s.content.match(/\bON (?:ONLY )?public\.(\w+)[\s(]/);
      if (m) found = m[1];
      break;
    }

    case 'FK CONSTRAINT': {
      found = tableNames.find(t => s.name === t || s.name.startsWith(t + ' '));
      if (!found) {
        const m = s.content.match(/ALTER TABLE ONLY public\.(\w+)/);
        if (m) found = m[1];
      }
      break;
    }
  }

  if (found && tableMap[found]) {
    tableMap[found].items.push(s);
  }
});

// Write one file per table
let count = 0;
for (const [tableName, data] of Object.entries(tableMap)) {
  const parts = data.items.map(s =>
    `--\n-- Name: ${s.name}; Type: ${s.type}; Schema: ${s.schema};\n--\n\n${s.content}`
  );
  fs.writeFileSync(
    path.join(outputDir, `${tableName}.sql`),
    parts.join('\n\n\n'),
    'utf8'
  );
  count++;
}

console.log(`Done — created ${count} files in ${outputDir}`);
