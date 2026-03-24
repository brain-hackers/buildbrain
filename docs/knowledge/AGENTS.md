This directory contains PDFs and texts that explains the inside of SHARP Brain, a series of e-dictionary sold by SHARP, for coding agents.

For text searching purpose, all PDFs are converted and explained into a corresponding Markdown with the same file name but the extension.


# Converting PDF to md

If the user of a coding agent requests the agent to convert the PDF into text, the agent must follow the rule:

- The slide number and the position of the Markdown document must be preserved; to achieve this, the Markdown document must have first level headers with the page number like "# Page 01" .
- The Markdown version is like a "text-only technical document version" of the PDF. Not only just converting texts in the PDF, agents must explain the topic based on the understanding of the visual slides.
- Future session of coding agents will understand the thing by reading the Markdown. Make the text simple and not redundant.
- Describe an abstract in the beginning of the Markdown.
- The resulting output must have the same file name as the original PDF but the extension ".md".

