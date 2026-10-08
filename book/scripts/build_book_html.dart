import 'dart:io';

void main() {
  final chaptersDir = Directory('book/chapters');
  if (!chaptersDir.existsSync()) {
    print('Error: book/chapters directory not found.');
    return;
  }

  // Ensure docs/book directory exists
  final outDir = Directory('docs/book');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  // Copy SVG assets into docs/book/assets/figures/
  final svgSource = File('book/assets/figures/sample_payoff.svg');
  if (svgSource.existsSync()) {
    final svgTargetDir = Directory('docs/book/assets/figures');
    if (!svgTargetDir.existsSync()) svgTargetDir.createSync(recursive: true);
    svgSource.copySync('docs/book/assets/figures/sample_payoff.svg');
  }

  final chapterFiles = chaptersDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md') || f.path.endsWith('.qmd'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final StringBuffer bodyContent = StringBuffer();
  final List<Map<String, String>> tocEntries = [];

  for (final file in chapterFiles) {
    final content = file.readAsStringSync();
    final filename = file.uri.pathSegments.last;
    
    // Extract first # header for title
    final lines = content.split('\n');
    String title = filename;
    for (final line in lines) {
      if (line.startsWith('# ')) {
        title = line.substring(2).trim();
        break;
      }
    }

    final sectionId = filename.replaceAll('.', '-').replaceAll('_', '-');
    tocEntries.add({'id': sectionId, 'title': title});

    bodyContent.writeln('<section id="$sectionId" class="book-chapter">');
    bodyContent.writeln(markdownToHtmlSimple(content));
    bodyContent.writeln('</section>');
    bodyContent.writeln('<hr class="chapter-divider" />');
  }

  final html = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Options Tools Book - Realist Options Trading</title>
  <!-- KaTeX for math rendering -->
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css">
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css"></script>
  <style>
    :root {
      --bg: #0f111a;
      --card-bg: #181a26;
      --sidebar-bg: #131520;
      --text: #e1e4ee;
      --text-muted: #8b92a8;
      --accent: #58a6ff;
      --border: #282c3d;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: var(--bg);
      color: var(--text);
      display: flex;
      min-height: 100vh;
      line-height: 1.6;
    }
    aside {
      width: 280px;
      background: var(--sidebar-bg);
      border-right: 1px solid var(--border);
      padding: 24px;
      position: sticky;
      top: 0;
      height: 100vh;
      overflow-y: auto;
    }
    aside h2 {
      font-size: 1.1rem;
      margin-top: 0;
      color: var(--accent);
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }
    aside ul {
      list-style: none;
      padding: 0;
      margin: 0;
    }
    aside li {
      margin-bottom: 12px;
    }
    aside a {
      color: var(--text-muted);
      text-decoration: none;
      font-size: 0.95rem;
      transition: color 0.2s;
    }
    aside a:hover {
      color: var(--text);
    }
    main {
      flex: 1;
      max-width: 860px;
      margin: 0 auto;
      padding: 40px;
    }
    .book-chapter {
      margin-bottom: 60px;
    }
    h1 { font-size: 2.2rem; color: #ffffff; border-bottom: 1px solid var(--border); padding-bottom: 12px; }
    h2 { font-size: 1.5rem; color: var(--accent); margin-top: 32px; }
    h3 { font-size: 1.2rem; color: #d0d7de; }
    p, li { font-size: 1.05rem; color: var(--text); }
    code { background: #212636; color: #f0883e; padding: 2px 6px; border-radius: 4px; font-family: monospace; }
    pre { background: #161b22; padding: 16px; border-radius: 8px; overflow-x: auto; border: 1px solid var(--border); }
    pre code { background: none; padding: 0; }
    img { max-width: 100%; height: auto; border-radius: 8px; margin: 20px 0; border: 1px solid var(--border); }
    .chapter-divider { border: 0; height: 1px; background: var(--border); margin: 60px 0; }
    blockquote { border-left: 4px solid var(--accent); padding-left: 16px; margin: 0; color: var(--text-muted); }
  </style>
</head>
<body>
  <aside>
    <h2>Options Book</h2>
    <ul>
      ${tocEntries.map((e) => '<li><a href="#${e['id']}">${e['title']}</a></li>').join('\n      ')}
    </ul>
  </aside>
  <main>
    ${bodyContent.toString()}
  </main>
</body>
</html>
''';

  final outFile = File('docs/book/index.html');
  outFile.writeAsStringSync(html);
  print('Successfully compiled Web Book to: ${outFile.path}');
}

String markdownToHtmlSimple(String md) {
  final lines = md.split('\n');
  final sb = StringBuffer();
  bool inList = false;
  bool inCode = false;

  for (var line in lines) {
    if (line.startsWith('```')) {
      if (inCode) {
        sb.writeln('</code></pre>');
        inCode = false;
      } else {
        sb.writeln('<pre><code>');
        inCode = true;
      }
      continue;
    }
    if (inCode) {
      sb.writeln(escapeHtml(line));
      continue;
    }

    if (line.startsWith('# ')) {
      sb.writeln('<h1>${escapeHtml(line.substring(2))}</h1>');
    } else if (line.startsWith('## ')) {
      sb.writeln('<h2>${escapeHtml(line.substring(3))}</h2>');
    } else if (line.startsWith('### ')) {
      sb.writeln('<h3>${escapeHtml(line.substring(4))}</h3>');
    } else if (line.startsWith('- ')) {
      if (!inList) {
        sb.writeln('<ul>');
        inList = true;
      }
      sb.writeln('<li>${formatInline(line.substring(2))}</li>');
    } else if (line.trim().isEmpty) {
      if (inList) {
        sb.writeln('</ul>');
        inList = false;
      }
    } else if (line.startsWith('![')) {
      final match = RegExp(r'!\[(.*?)\]\((.*?)\)').firstMatch(line);
      if (match != null) {
        final alt = match.group(1);
        var src = match.group(2)!;
        // Fix relative path for docs/book/ index.html context
        if (src.startsWith('../assets/')) {
          src = src.replaceFirst('../assets/', 'assets/');
        }
        sb.writeln('<img src="$src" alt="${escapeHtml(alt ?? '')}" />');
      }
    } else {
      if (inList) {
        sb.writeln('</ul>');
        inList = false;
      }
      sb.writeln('<p>${formatInline(line)}</p>');
    }
  }

  if (inList) sb.writeln('</ul>');
  if (inCode) sb.writeln('</code></pre>');

  return sb.toString();
}

String escapeHtml(String text) {
  return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}

String formatInline(String text) {
  var t = escapeHtml(text);
  // Bold
  t = t.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => '<strong>${m[1]}</strong>');
  // Inline code
  t = t.replaceAllMapped(RegExp(r'`(.*?)`'), (m) => '<code>${m[1]}</code>');
  return t;
}
