# CSS Properties

Complete reference for all CSS properties supported by GTML.

## Layout

### Display

```css
display: flex;    /* Flexbox layout (default) */
display: block;   /* Block layout */
display: none;    /* Hidden */
```

### Flex Direction

```css
flex-direction: column;  /* Vertical (default) */
flex-direction: row;     /* Horizontal */
```

### Flex Wrap

```css
flex-wrap: nowrap;        /* Single line (default) */
flex-wrap: wrap;          /* Wrap to new lines */
flex-wrap: wrap-reverse;  /* Wrap in reverse */
```

### Align Items (Cross-axis)

```css
align-items: flex-start;  /* Align to start */
align-items: center;      /* Center alignment */
align-items: flex-end;    /* Align to end */
align-items: stretch;     /* Stretch to fill (default) */
```

### Align Self

Override parent's `align-items` for a specific child:

```css
align-self: flex-start;
align-self: center;
align-self: flex-end;
align-self: stretch;
```

### Justify Content (Main-axis)

```css
justify-content: flex-start;     /* Pack at start (default) */
justify-content: center;         /* Center items */
justify-content: flex-end;       /* Pack at end */
justify-content: space-between;  /* Even space between */
justify-content: space-around;   /* Even space around */
justify-content: space-evenly;   /* Equal space everywhere */
```

### Gap

```css
gap: 16px;         /* All gaps */
row-gap: 12px;     /* Vertical gaps */
column-gap: 8px;   /* Horizontal gaps */
```

### Flex Grow & Shrink

```css
flex-grow: 1;    /* Allow growing */
flex-grow: 0;    /* Don't grow (default) */
flex-shrink: 1;  /* Allow shrinking (default) */
flex-shrink: 0;  /* Don't shrink */
flex-basis: 200px;  /* Initial size */
```

### Order

Control the visual order of flex items:

```css
.first { order: -1; }  /* Move to front */
.last { order: 1; }    /* Move to back */
/* Default order is 0 */
```

## Dimensions

### Width & Height

```css
width: 200px;     /* Fixed pixel width */
width: 50%;       /* Percentage of parent */
width: auto;      /* Automatic sizing */

height: 100px;
height: 100%;
```

### Min/Max Constraints

```css
min-width: 100px;
max-width: 400px;
min-height: 50px;
max-height: 300px;
```

## Spacing

### Margin

```css
margin: 16px;           /* All sides */
margin-top: 8px;
margin-right: 12px;
margin-bottom: 8px;
margin-left: 12px;
```

### Padding

```css
padding: 16px;          /* All sides */
padding-top: 8px;
padding-right: 12px;
padding-bottom: 8px;
padding-left: 12px;
```

> **Note:** Multi-value shorthand (`margin: 10px 20px`) is not supported. Use individual properties.

## Background

### Solid Color

```css
background-color: #1a1a2e;
background-color: rgb(26, 26, 46);
background-color: rgba(26, 26, 46, 0.9);
background-color: transparent;
```

### Linear Gradient

```css
/* Direction keywords */
background: linear-gradient(to right, #ff0000, #0000ff);
background: linear-gradient(to bottom, #000, #333);
background: linear-gradient(to top left, red, blue);

/* Angle */
background: linear-gradient(45deg, #ff0000, #0000ff);
background: linear-gradient(90deg, red, yellow, green);

/* Color stops with positions */
background: linear-gradient(to bottom, #000 0%, #333 50%, #000 100%);
```

### Radial Gradient

```css
background: radial-gradient(circle, #ffffff, #000000);
background: radial-gradient(ellipse, white 0%, black 100%);
```

### Background Image

```css
background: url(res://assets/bg.png);
background-image: url(res://textures/pattern.png);
```

## Border

### Border Shorthand

```css
border: 2px solid #3a3a5e;
border: 1px dashed #ff0000;
border: 3px dotted rgba(255, 255, 255, 0.5);
```

**Supported styles:** `solid`, `dashed`, `dotted`, `none`

### Individual Borders

```css
border-top: 1px solid #fff;
border-right: 2px solid #fff;
border-bottom: 1px solid #fff;
border-left: 2px solid #fff;
```

### Border Properties

```css
border-width: 2px;           /* All sides */
border-top-width: 1px;
border-right-width: 2px;
border-bottom-width: 1px;
border-left-width: 2px;

border-color: #3a3a5e;       /* All sides */
border-top-color: #fff;
border-right-color: #fff;
border-bottom-color: #fff;
border-left-color: #fff;
```

### Border Radius

```css
border-radius: 8px;                  /* All corners */
border-top-left-radius: 8px;
border-top-right-radius: 8px;
border-bottom-left-radius: 8px;
border-bottom-right-radius: 8px;
```

## Typography

### Text Color

```css
color: #ffffff;
color: rgb(255, 255, 255);
color: rgba(255, 255, 255, 0.8);
```

### Font Size

```css
font-size: 16px;
font-size: 24px;
```

### Font Family

```css
font-family: 'Orbitron';
font-family: 'Rajdhani';
```

> **Note:** Fonts must be registered in the GmlView `fonts` dictionary. See [Fonts & Typography](fonts-and-typography.md).

### Font Weight

```css
font-weight: normal;    /* 400 */
font-weight: bold;      /* 700 */
font-weight: 100;       /* Thin */
font-weight: 300;       /* Light */
font-weight: 500;       /* Medium */
font-weight: 600;       /* Semibold */
font-weight: 800;       /* Extrabold */
font-weight: 900;       /* Black */
```

**Keywords:** `thin`, `light`, `normal`, `medium`, `semibold`, `bold`, `extrabold`, `black`

### Text Alignment

```css
text-align: left;     /* Left-aligned (default) */
text-align: center;   /* Centered */
text-align: right;    /* Right-aligned */
text-align: justify;  /* Justified */
```

### Letter Spacing

```css
letter-spacing: 2px;
letter-spacing: 0.1em;  /* Relative to font size */
```

### Word Spacing

```css
word-spacing: 4px;
```

### Line Height

```css
line-height: 24px;
```

### Text Indent

```css
text-indent: 20px;
```

### Text Transform

```css
text-transform: uppercase;   /* ALL CAPS */
text-transform: lowercase;   /* all lowercase */
text-transform: capitalize;  /* First Letter Caps */
text-transform: none;        /* No transform */
```

### Text Decoration

```css
text-decoration: underline;
text-decoration: line-through;
text-decoration: overline;
text-decoration: none;
```

### Text Overflow

```css
text-overflow: clip;      /* Clip text */
text-overflow: ellipsis;  /* Show ... */
```

### White Space

```css
white-space: normal;   /* Wrap normally */
white-space: nowrap;   /* No wrapping */
white-space: pre;      /* Preserve whitespace */
```

## Effects

### Opacity

```css
opacity: 1;     /* Fully visible */
opacity: 0.5;   /* Semi-transparent */
opacity: 0;     /* Invisible */
```

### Box Shadow

```css
/* offset-x offset-y blur spread color */
box-shadow: 4px 4px 8px rgba(0, 0, 0, 0.5);
box-shadow: 0 2px 4px 2px #000000;
box-shadow: inset 0 0 10px rgba(0, 0, 0, 0.3);  /* Inset shadow */
```

### Text Shadow

```css
/* offset-x offset-y blur color */
text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
text-shadow: 0 0 10px #00d4ff;  /* Glow effect */
```

### Outline

```css
outline: 2px solid #ff0000;
outline: 1px dashed #00ff00;
outline-offset: 4px;  /* Space between border and outline */
```

## Cursor

```css
cursor: pointer;       /* Hand cursor */
cursor: text;          /* Text cursor */
cursor: move;          /* Move cursor */
cursor: not-allowed;   /* Forbidden cursor */
cursor: grab;          /* Grab hand */
cursor: grabbing;      /* Grabbing hand */
cursor: crosshair;     /* Crosshair */
cursor: help;          /* Help cursor */
cursor: wait;          /* Wait/loading */
cursor: progress;      /* Progress indicator */
cursor: none;          /* Hide cursor */

/* Resize cursors */
cursor: n-resize;      /* North resize */
cursor: e-resize;      /* East resize */
cursor: s-resize;      /* South resize */
cursor: w-resize;      /* West resize */
cursor: nw-resize;     /* Northwest resize */
cursor: ne-resize;     /* Northeast resize */
cursor: sw-resize;     /* Southwest resize */
cursor: se-resize;     /* Southeast resize */
cursor: ew-resize;     /* East-west resize */
cursor: ns-resize;     /* North-south resize */
cursor: col-resize;    /* Column resize */
cursor: row-resize;    /* Row resize */
```

## Overflow & Visibility

### Overflow

```css
overflow: visible;  /* Show overflow (default) */
overflow: hidden;   /* Clip overflow */
overflow: scroll;   /* Always show scrollbars */
overflow: auto;     /* Show scrollbars when needed */

overflow-x: hidden;  /* Horizontal only */
overflow-y: scroll;  /* Vertical only */
```

> **Note:** Scroll requires explicit height to function.

### Visibility

```css
visibility: visible;  /* Shown (default) */
visibility: hidden;   /* Hidden but takes space */
```

## List Styling

```css
list-style-type: disc;                 /* Bullet (default for ul) */
list-style-type: circle;               /* Circle */
list-style-type: square;               /* Square */
list-style-type: none;                 /* No marker */
list-style-type: decimal;              /* 1, 2, 3 (default for ol) */
list-style-type: decimal-leading-zero; /* 01, 02, 03 */
list-style-type: lower-alpha;          /* a, b, c */
list-style-type: upper-alpha;          /* A, B, C */
list-style-type: lower-roman;          /* i, ii, iii */
list-style-type: upper-roman;          /* I, II, III */
```

## Color Values

### Hex Colors

```css
color: #RRGGBB;  /* Full hex */
color: #RGB;     /* Short hex */
color: #ff5500;
color: #f50;
```

### RGB/RGBA

```css
color: rgb(255, 85, 0);
color: rgba(255, 85, 0, 0.8);  /* With alpha */
```

### Named Colors

Supported color names:
- `white`, `black`
- `red`, `green`, `blue`
- `yellow`, `cyan`, `magenta`
- `gray`, `grey`
- `orange`, `purple`, `pink`
- `transparent`

## See Also

- [CSS Selectors](css-selectors.md) - Targeting elements
- [Layout & Flexbox](layout-and-flexbox.md) - Layout details
- [Transitions](transitions.md) - Animated properties
- [Fonts & Typography](fonts-and-typography.md) - Font configuration
- [Limitations](limitations.md) - What's not supported
