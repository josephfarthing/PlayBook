"""
EPUB to Playdate PDB Converter
==============================

This script extracts text from EPUB files, automatically parses chapters,
injects invisible soft hyphens for optimal Playdate screen rendering, and
bundles everything into a custom .pdb (Playdate Book) format alongside an
optional JSON glossary.

Dependencies:
-------------
Ensure you have the required libraries installed before running:
    pip install ebooklib beautifulsoup4 pyphen

Usage:
------
Single File Conversion:
    python build_pdb.py "book.epub" "book.pdb"

Batch Directory Conversion:
    python build_pdb.py "path/to/epub/folder" "path/to/output/folder"

With Glossary (JSON file mapping words to definitions):
    python build_pdb.py "book.epub" "book.pdb" --glossary "defs.json"

With Custom Hyphenation Language (defaults to British English 'en_GB'):
    python build_pdb.py "book.epub" "book.pdb" --lang "en_US"

Arguments:
----------
    input       : Path to the source .epub file or directory.
    output      : Path to the target .pdb file or directory.
    --glossary  : (Optional) Path to a JSON dictionary file for word lookups.
    --lang      : (Optional) Pyphen language dictionary code for hyphenation behaviour.
"""

import json
import argparse
import os
import glob
import re
import urllib.request
import ebooklib
from ebooklib import epub
from bs4 import BeautifulSoup
import pyphen

COMMON_WORDS_URL = "https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english-usa-no-swears.txt"
COMMON_WORDS_CACHE = "common_words_10k.txt"

def get_common_words():
    """Loads or fetches the top 10,000 most common English words."""
    if os.path.exists(COMMON_WORDS_CACHE):
        with open(COMMON_WORDS_CACHE, "r", encoding="utf-8") as f:
            return set(line.strip().lower() for line in f if line.strip())
            
    print("Downloading common words reference list (one-time setup)...")
    try:
        req = urllib.request.Request(COMMON_WORDS_URL, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            data = response.read().decode('utf-8')
            with open(COMMON_WORDS_CACHE, "w", encoding="utf-8") as f:
                f.write(data)
            return set(data.split())
    except Exception as e:
        print(f"Warning: Could not download common words list ({e}). Filtering by book vocabulary only.")
        return set()

def build_pdb(input_epub, output_pdb, glossary_file=None, lang='en_GB'):
    print(f"\nOpening EPUB: {input_epub}")
    book = epub.read_epub(input_epub)
    
    dic = pyphen.Pyphen(lang=lang)
    metadata = { "chapters": [], "glossary": {} }
    
    # Load raw dictionary if provided
    master_dictionary = {}
    if glossary_file and os.path.exists(glossary_file):
        print(f"Loading master dictionary from {glossary_file}...")
        with open(glossary_file, 'r', encoding='utf-8') as gf:
            master_dictionary = json.load(gf)
            
    print("Extracting text and building chapters...")
    full_text = ""
    current_byte_index = 1 
    
    for item_id, _ in book.spine:
        item = book.get_item_with_id(item_id)
        if item.get_type() == ebooklib.ITEM_DOCUMENT:
            soup = BeautifulSoup(item.get_content(), 'html.parser')
            
            title_tag = soup.find(['h1', 'h2', 'h3'])
            chapter_title = title_tag.get_text(strip=True) if title_tag else f"Chapter {len(metadata['chapters']) + 1}"
            
            metadata["chapters"].append({"title": chapter_title, "index": current_byte_index})
            
            for element in soup.find_all(['p', 'div', 'h1', 'h2', 'h3']):
                raw_text = element.get_text(separator=' ')
                text = " ".join(raw_text.split())
                if text:
                    # Inject soft hyphens (\u00AD) into alphabetical sequences
                    text = re.sub(r'[A-Za-z]+', lambda m: dic.inserted(m.group(), hyphen='\u00AD'), text)
                    
                    chunk = text + "\n\n"
                    full_text += chunk
                    current_byte_index += len(chunk.encode('utf-8'))
    
    # Build tailored book glossary
    if master_dictionary:
        print("Filtering glossary for uncommon words present in this book...")
        common_words = get_common_words()
        
        # Extract unique words from clean text (stripping soft hyphens)
        clean_text = full_text.replace('\u00AD', '').lower()
        book_words = set(re.findall(r'\b[a-z]{3,}\b', clean_text))
        
        filtered_glossary = {}
        for word in book_words:
            if word not in common_words and word in master_dictionary:
                filtered_glossary[word] = master_dictionary[word]
                
        metadata["glossary"] = filtered_glossary
        glossary_bytes = len(json.dumps(filtered_glossary).encode('utf-8'))
        print(f"Glossary optimised: {len(filtered_glossary)} unique definitions ({glossary_bytes // 1024} KB).")
                        
    print(f"Writing PDB bundle to {output_pdb}...")
    with open(output_pdb, 'wb') as f:
        f.write(json.dumps(metadata).encode('utf-8'))
        f.write(b'\n---PDB---\n')
        f.write(full_text.encode('utf-8'))
                
    total_size_mb = os.path.getsize(output_pdb) / (1024 * 1024)
    print(f"Complete: {output_pdb} ({total_size_mb:.2f} MB)")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Convert EPUB to Playdate PDB")
    parser.add_argument("input", help="Input .epub file or directory")
    parser.add_argument("output", help="Output .pdb file or directory")
    parser.add_argument("--glossary", help="Optional JSON glossary", default=None)
    parser.add_argument("--lang", help="Hyphenation language code (e.g. en_GB, en_US)", default="en_GB")
    args = parser.parse_args()
    
    if os.path.isdir(args.input):
        if not os.path.exists(args.output): os.makedirs(args.output)
        for epub_path in glob.glob(os.path.join(args.input, "*.epub")):
            out_path = os.path.join(args.output, os.path.splitext(os.path.basename(epub_path))[0] + ".pdb")
            build_pdb(epub_path, out_path, args.glossary, args.lang)
    else:
        out_path = os.path.join(args.output, os.path.splitext(os.path.basename(args.input))[0] + ".pdb") if os.path.isdir(args.output) else args.output
        build_pdb(args.input, out_path, args.glossary, args.lang)