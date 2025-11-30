# Fonts and Typography

GTML supports custom fonts and various text styling properties. This guide covers font configuration, typography properties, and best practices.

## Font Configuration

### Registering Fonts

Custom fonts must be registered in the GmlView `fonts` dictionary before use:

**In the Inspector:**

Set the `fonts` property as a Dictionary:
```
Key: "Orbitron"    Value: res://assets/fonts/Orbitron-Regular.ttf
Key: "Rajdhani"    Value: res://assets/fonts/Rajdhani-Regular.ttf
```

**In GDScript:**

```gdscript
func _ready():
    $GmlView.fonts = {
        "Orbitron": preload("res://assets/fonts/Orbitron-Regular.ttf"),
        "Rajdhani": preload("res://assets/fonts/Rajdhani-Regular.ttf"),
        "Roboto": preload("res://assets/fonts/Roboto-Regular.ttf")
    }
```

### Using Fonts in CSS

```css
h1 {
    font-family: 'Orbitron';
    font-size: 32px;
}

p {
    font-family: 'Rajdhani';
    font-size: 16px;
}

.code {
    font-family: 'Roboto Mono';
    font-size: 14px;
}
```

> **Note:** Only the first font in a font stack is used. Fallback fonts are not supported.

## Font Size

Set text size in pixels:

```css
h1 { font-size: 32px; }
h2 { font-size: 24px; }
h3 { font-size: 20px; }
p  { font-size: 16px; }
small { font-size: 12px; }
```

### Default Heading Sizes

GmlView provides configurable defaults:

| Heading | Default Size |
|---------|-------------|
| `h1` | 32px |
| `h2` | 24px |
| `h3` | 20px |
| `h4` | 16px |
| `h5` | 13px |
| `h6` | 11px |
| `p` | 16px |

Configure in the Inspector or CSS overrides them.

## Font Weight

```css
/* Numeric values (100-900) */
font-weight: 100;  /* Thin */
font-weight: 200;  /* Extra Light */
font-weight: 300;  /* Light */
font-weight: 400;  /* Normal */
font-weight: 500;  /* Medium */
font-weight: 600;  /* Semi Bold */
font-weight: 700;  /* Bold */
font-weight: 800;  /* Extra Bold */
font-weight: 900;  /* Black */

/* Keyword values */
font-weight: thin;       /* 100 */
font-weight: light;      /* 300 */
font-weight: normal;     /* 400 */
font-weight: medium;     /* 500 */
font-weight: semibold;   /* 600 */
font-weight: bold;       /* 700 */
font-weight: extrabold;  /* 800 */
font-weight: black;      /* 900 */
```

> **Note:** Font weight is simulated using text outline. For true font weights, provide separate font files for each weight.

### Example with Multiple Weights

```gdscript
# Register multiple weights of same font family
$GmlView.fonts = {
    "Roboto-Light": preload("res://fonts/Roboto-Light.ttf"),
    "Roboto": preload("res://fonts/Roboto-Regular.ttf"),
    "Roboto-Bold": preload("res://fonts/Roboto-Bold.ttf")
}
```

```css
.light { font-family: 'Roboto-Light'; }
.regular { font-family: 'Roboto'; }
.bold { font-family: 'Roboto-Bold'; }
```

## Text Color

```css
/* Hex colors */
color: #ffffff;
color: #00d4ff;

/* RGB/RGBA */
color: rgb(255, 255, 255);
color: rgba(255, 255, 255, 0.8);

/* Named colors */
color: white;
color: transparent;
```

## Text Alignment

```css
text-align: left;     /* Left-aligned (default) */
text-align: center;   /* Centered */
text-align: right;    /* Right-aligned */
text-align: justify;  /* Justified */
```

```html
<p class="left">Left aligned text.</p>
<p class="center">Centered text.</p>
<p class="right">Right aligned text.</p>
```

## Letter Spacing

```css
/* Pixel value */
letter-spacing: 2px;
letter-spacing: -1px;  /* Tighter */

/* Em value (relative to font size) */
letter-spacing: 0.1em;
letter-spacing: 0.05em;
```

> **Note:** Letter spacing is simulated using Unicode space characters.

## Word Spacing

```css
word-spacing: 4px;
word-spacing: 8px;
```

## Line Height

```css
line-height: 24px;
line-height: 32px;
```

## Text Indent

Indent the first line of text:

```css
text-indent: 20px;
text-indent: 40px;
```

## Text Transform

```css
text-transform: uppercase;   /* UPPERCASE */
text-transform: lowercase;   /* lowercase */
text-transform: capitalize;  /* Capitalize Each Word */
text-transform: none;        /* No Transform */
```

```html
<p class="uppercase">this becomes uppercase</p>
<p class="capitalize">this gets capitalized</p>
```

## Text Decoration

```css
text-decoration: underline;
text-decoration: line-through;
text-decoration: overline;
text-decoration: none;
```

```html
<span class="underline">Underlined text</span>
<span class="strikethrough">Deleted text</span>
```

## Text Shadow

Add shadow effects to text:

```css
/* offset-x offset-y blur color */
text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);

/* Glow effect */
text-shadow: 0 0 10px #00d4ff;

/* Hard shadow */
text-shadow: 2px 2px 0 #000000;
```

```html
<h1 class="glow">Glowing Title</h1>
<h1 class="shadow">Shadowed Title</h1>
```

```css
.glow {
    color: #00d4ff;
    text-shadow: 0 0 20px #00d4ff;
}

.shadow {
    color: #ffffff;
    text-shadow: 3px 3px 0 #000000;
}
```

## Text Overflow

Handle text that exceeds its container:

```css
.truncate {
    width: 200px;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
}
```

**Values:**
- `clip` - Simply clip the text
- `ellipsis` - Show `...` at the end

## White Space

Control how whitespace is handled:

```css
white-space: normal;   /* Collapse whitespace, wrap text */
white-space: nowrap;   /* Collapse whitespace, no wrap */
white-space: pre;      /* Preserve whitespace */
```

## Typography Examples

### Heading Hierarchy

```html
<h1>Main Title</h1>
<h2>Section Title</h2>
<h3>Subsection</h3>
<p>Body text goes here with details.</p>
```

```css
h1 {
    font-family: 'Orbitron';
    font-size: 36px;
    font-weight: bold;
    color: #ffffff;
    letter-spacing: 2px;
    text-transform: uppercase;
}

h2 {
    font-family: 'Orbitron';
    font-size: 24px;
    font-weight: semibold;
    color: #e0e0e0;
    letter-spacing: 1px;
}

h3 {
    font-family: 'Rajdhani';
    font-size: 18px;
    font-weight: medium;
    color: #aaaacc;
}

p {
    font-family: 'Rajdhani';
    font-size: 16px;
    line-height: 24px;
    color: #cccccc;
}
```

### Game Title Style

```html
<div class="title-container">
    <h1 class="game-title">STARFIELD</h1>
    <p class="subtitle">A Space Adventure</p>
</div>
```

```css
.title-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
}

.game-title {
    font-family: 'Orbitron';
    font-size: 48px;
    font-weight: black;
    color: #00d4ff;
    letter-spacing: 8px;
    text-shadow: 0 0 30px rgba(0, 212, 255, 0.5);
}

.subtitle {
    font-family: 'Rajdhani';
    font-size: 16px;
    color: #6b7d93;
    letter-spacing: 4px;
    text-transform: uppercase;
}
```

### Button Text Styles

```css
button {
    font-family: 'Rajdhani';
    font-size: 14px;
    font-weight: semibold;
    text-transform: uppercase;
    letter-spacing: 1px;
}

button.large {
    font-size: 18px;
    letter-spacing: 2px;
}

button.small {
    font-size: 12px;
}
```

### Label Styles

```css
label {
    font-family: 'Rajdhani';
    font-size: 12px;
    color: #888899;
    text-transform: uppercase;
    letter-spacing: 1px;
}

.value {
    font-family: 'Roboto Mono';
    font-size: 14px;
    color: #ffffff;
}
```

## Limitations

- **No true italics** without custom italic font files
- **Font weight simulation** uses outline (not true bold)
- **No font fallbacks** - only first font is used
- **Letter spacing simulated** with Unicode spaces
- **No web fonts** - must use local font files
- **No CSS variables** for font values

## Best Practices

### 1. Limit Font Count

```gdscript
# Good - 2-3 fonts
fonts = {
    "Heading": preload("res://fonts/Heading.ttf"),
    "Body": preload("res://fonts/Body.ttf")
}

# Avoid - too many fonts
```

### 2. Use Consistent Sizes

```css
/* Define a scale */
.text-xs { font-size: 12px; }
.text-sm { font-size: 14px; }
.text-md { font-size: 16px; }
.text-lg { font-size: 20px; }
.text-xl { font-size: 24px; }
.text-2xl { font-size: 32px; }
```

### 3. Ensure Readability

```css
/* Good contrast */
p {
    color: #cccccc;
    background-color: #1a1a2e;  /* Sufficient contrast */
}

/* Appropriate line height for body text */
p {
    font-size: 16px;
    line-height: 24px;  /* 1.5x font size */
}
```

## See Also

- [CSS Properties](css-properties.md) - All text properties
- [HTML Elements](html-elements.md) - Text elements
- [Limitations](limitations.md) - Typography limitations
