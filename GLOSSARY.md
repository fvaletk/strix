# Strix

A personal reading assistant: the User saves web pages, gets a summary and tags for each, and asks questions across everything saved.

## Language

**User**:
The person who saves and reads Articles. There is one User today; every Article belongs to one.
_Avoid_: Reader, account, owner

**Article**:
The content saved from one web page URL, together with what Strix derives from it. An Article exists even when its content could not be extracted.
_Avoid_: Link, Bookmark, Item, Post, Document

**URL**:
The address an Article was saved from. It points at an Article; it is not the Article.
_Avoid_: Link (as a synonym for Article)

**Extraction**:
Turning the web page behind a URL into the readable text of an Article. An Article whose Extraction failed is kept and marked failed.
_Avoid_: Scraping, parsing, fetching

**Summary**:
A short English digest of one Article: a two-sentence TL;DR followed by its key points.
_Avoid_: Abstract, digest, synopsis

**Chunk**:
A contiguous passage of an Article's text, the unit Strix searches when answering a Question.
_Avoid_: Segment, passage, snippet

**Question**:
Something the User asks across all their Articles.
_Avoid_: Query, prompt, search

**Answer**:
Strix's reply to one Question, citing the Articles it drew on.
_Avoid_: Response, result

**Tag**:
A label naming what an Article is about. Tags are shared across a User's Articles: an existing Tag is reused whenever it fits, and a new one is created only when none does.
_Avoid_: Category, label, topic, keyword
