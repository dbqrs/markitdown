# MarkItDown installation script with right click processing.

* #### Installs Microsoft MarkItDown for Windows using a dedicated Python virtual environment. - https://github.com/microsoft/markitdown
* #### Uses Python 3.10 through 3.13 only.
* #### Avoids Python 3.14 due to current dependency problems.
* #### Installs FFmpeg to avoid pydub audio/video warnings.
* #### Adds a right-click menu option named "MarkItDown" for converting files to Markdown.

---

MarkItDown is a Microsoft open-source Python tool that converts many common file types into Markdown, which is a clean plain-text format that keeps useful structure like headings, lists, tables, and links. Microsoft describes it as being built mainly for LLMs and text-analysis pipelines, not for perfect human-facing document recreation.

In plain English: it takes messy files and turns them into clean text that AI tools can read much better.

It can convert things like:

| File type            | What MarkItDown does                              |
| -------------------- | ------------------------------------------------- |
| PDF                  | Extracts readable text into Markdown              |
| Word documents       | Converts document structure into Markdown         |
| PowerPoint           | Pulls slide content into text                     |
| Excel                | Converts sheets/tables into Markdown-style output |
| Images               | Can extract metadata and use OCR                  |
| Audio                | Can use metadata and speech transcription         |
| HTML, CSV, JSON, XML | Converts text-based data into Markdown            |
| ZIP files            | Can iterate through contents                      |
| YouTube URLs         | Can pull transcript-style content when supported  |
| EPUBs                | Converts ebook content                            |


Microsoft lists support for PDF, PowerPoint, Word, Excel, images, audio, HTML, text-based formats, ZIP files, YouTube URLs, EPUBs, and more.

### Why Markdown specifically?

Markdown is close to plain text but still supports structure. Microsoft notes that mainstream LLMs understand Markdown well and that Markdown conventions are token-efficient. The savings come from converting bulky or messy document content into clean Markdown, which is usually more compact and easier for an AI model to read. Microsoft says MarkItDown is designed for LLM/text-analysis pipelines and preserves useful structure like headings, lists, tables, and links rather than trying to recreate perfect visual layout.

One recent test write-up claimed about a 62% token reduction when converting a document through MarkItDown before sending it to an LLM, but that is one example, not a universal guarantee.

