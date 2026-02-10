Vue.component('message', {
  template: '#message_template',
  data() {
    return {};
  },
  computed: {
    textEscaped() {
      let s = this.template ? this.template : this.templates[this.templateId];

      if (this.template) {
        this.templateId = -1;
      }

      if (this.templateId == CONFIG.defaultTemplateId && this.args.length == 1) {
        s = this.templates[CONFIG.defaultAltTemplateId];
      }

      s = s.replace(/{(\d+)}/g, (match, number) => {
        const argEscaped =
          this.args[number] != undefined ? this.escape(this.args[number]) : match;

        if (number == 0 && this.color) {
          return this.colorizeOld(argEscaped);
        }
        return argEscaped;
      });

      return this.colorize(s);
    },
  },
  methods: {
    colorizeOld(str) {
      return `<span style="color: rgb(${this.color[0]}, ${this.color[1]}, ${this.color[2]})">${str}</span>`;
    },

    colorize(str) {
      let s =
        "<span>" +
        str.replace(/\^([0-9])/g, (str, color) => `</span><span class="color-${color}">`) +
        "</span>";

      // 🔥 Formatting styles
      const styleDict = {
        '*': 'font-weight: bold;',
        '_': 'text-decoration: underline;',
        '~': 'text-decoration: line-through;',
        '=': 'text-decoration: underline line-through;',
        '/': 'font-style: italic;',        // ✅ ADDED: italics
        'r': 'text-decoration: none; font-weight: normal; font-style: normal;',
      };

      const styleRegex = /\^(\*|_|=|~|\/|r)(.*?)(?=$|\^r)/;

      while (s.match(styleRegex)) {
        s = s.replace(styleRegex, (str, style, inner) => {
          return `<em style="${styleDict[style]}">${inner}</em>`;
        });
      }

      return s.replace(/<span[^>]*><\/span[^>]*>/g, '');
    },

    escape(unsafe) {
      return String(unsafe)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    },
  },
  props: {
    templates: {
      type: Object,
    },
    args: {
      type: Array,
    },
    template: {
      type: String,
      default: null,
    },
    templateId: {
      type: String,
      default: CONFIG.defaultTemplateId,
    },
    multiline: {
      type: Boolean,
      default: false,
    },
    color: {
      type: Array,
      default: false,
    },
  },
});
