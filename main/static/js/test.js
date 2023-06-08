resultComponent = new Vue({
  el: '#test',
  data: {
    data: [],
    current: 0,
    data_reduce: [],
    rect: {},
    zoomLevel: 1,
    extractData: {},
    suggestionData: {},
    testData: [],
    listColumn: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'AA', 'AB', 'AC', 'AD', 'AE', 'AF', 'AG', 'AH', 'AI', 'AJ', 'AK', 'AL', 'AM', 'AN', 'AO', 'AP', 'AQ', 'AR', 'AS', 'AT', 'AU', 'AV', 'AW', 'AX', 'AY', 'AZ', 'BA', 'BB', 'BC', 'BD', 'BE', 'BF', 'BG', 'BH', 'BI', 'BJ', 'BK', 'BL', 'BM', 'BN', 'BO', 'BP', 'BQ', 'BR', 'BS', 'BT', 'BU', 'BV', 'BW', 'BX', 'BY', 'BZ', 'CA', 'CB', 'CC', 'CD', 'CE', 'CF', 'CG', 'CH', 'CI', 'CJ', 'CK', 'CL', 'CM', 'CN', 'CO', 'CP', 'CQ', 'CR', 'CS', 'CT', 'CU', 'CV', 'CW', 'CX', 'CY', 'CZ', 'DA', 'DB', 'DC', 'DD', 'DE', 'DF', 'DG', 'DH', 'DI', 'DJ', 'DK', 'DL', 'DM', 'DN', 'DO', 'DP', 'DQ', 'DR', 'DS', 'DT', 'DU', 'DV', 'DW', 'DX', 'DY', 'DZ', 'EA', 'EB', 'EC', 'ED', 'EE', 'EF', 'EG', 'EH', 'EI', 'EK', 'EL', 'EM', 'EN', 'EO', 'EP', 'EQ', 'ER', 'ES', 'ET', 'EV', 'EX', 'EY', 'EZ', 'FA', 'FB', 'FC', 'FD', 'FE', 'FF', 'FG', 'FH', 'FI', 'FK', 'FL', 'FM', 'FN', 'FO', 'FP', 'FQ', 'FR', 'FS', 'FT', 'FV', 'FX', 'FY', 'FZ', 'GA', 'GB', 'GC', 'GD', 'GE', 'GF', 'GG', 'GH', 'GI', 'GK', 'GL', 'GM', 'GN', 'GO', 'GP', 'GQ', 'GR', 'GS', 'GT', 'GV', 'GX', 'GY', 'GZ', 'HA', 'HB', 'HC', 'HD', 'HE', 'HF', 'HG', 'HH', 'HI', 'HK', 'HL', 'HM', 'HN', 'HO', 'HP', 'HQ', 'HR', 'HS', 'HT', 'HV', 'HX', 'HY', 'HZ', 'IA', 'IB', 'IC', 'ID', 'IE', 'IF', 'IG', 'IH', 'II', 'IK', 'IL', 'IM', 'IN', 'IO', 'IP', 'IQ', 'IR', 'IS', 'IT', 'IV', 'IX', 'IY', 'IZ', 'KA', 'KB', 'KC', 'KD', 'KE', 'KF', 'KG', 'KH', 'KI', 'KK', 'KL', 'KM', 'KN', 'KO', 'KP', 'KQ', 'KR', 'KS', 'KT', 'KV', 'KX', 'KY', 'KZ', 'LA', 'LB', 'LC', 'LD', 'LE', 'LF', 'LG', 'LH', 'LI', 'LK', 'LL', 'LM', 'LN', 'LO', 'LP', 'LQ', 'LR', 'LS', 'LT', 'LV', 'LX', 'LY', 'LZ', 'MA', 'MB', 'MC', 'MD', 'ME', 'MF', 'MG', 'MH', 'MI', 'MK', 'ML', 'MM', 'MN', 'MO', 'MP', 'MQ', 'MR', 'MS', 'MT', 'MV', 'MX', 'MY', 'MZ', 'NA', 'NB', 'NC', 'ND', 'NE', 'NF', 'NG', 'NH', 'NI', 'NK', 'NL', 'NM', 'NN', 'NO', 'NP', 'NQ', 'NR', 'NS', 'NT', 'NV', 'NX', 'NY', 'NZ', 'OA', 'OB', 'OC', 'OD', 'OE', 'OF', 'OG', 'OH', 'OI', 'OK', 'OL', 'OM', 'ON', 'OO', 'OP', 'OQ', 'OR', 'OS', 'OT', 'OV', 'OX', 'OY', 'OZ', 'PA', 'PB', 'PC', 'PD', 'PE', 'PF', 'PG', 'PH', 'PI', 'PK', 'PL', 'PM', 'PN', 'PO', 'PP', 'PQ', 'PR', 'PS', 'PT', 'PV', 'PX', 'PY', 'PZ', 'QA', 'QB', 'QC', 'QD', 'QE', 'QF', 'QG', 'QH', 'QI', 'QK', 'QL', 'QM', 'QN', 'QO', 'QP', 'QQ', 'QR', 'QS', 'QT', 'QV', 'QX', 'QY', 'QZ', 'RA', 'RB', 'RC', 'RD', 'RE', 'RF', 'RG', 'RH', 'RI', 'RK', 'RL', 'RM', 'RN', 'RO', 'RP', 'RQ', 'RR', 'RS', 'RT', 'RV', 'RX', 'RY', 'RZ', 'SA', 'SB', 'SC', 'SD', 'SE', 'SF', 'SG', 'SH', 'SI', 'SK', 'SL', 'SM', 'SN', 'SO', 'SP', 'SQ', 'SR', 'SS', 'ST', 'SV', 'SX', 'SY', 'SZ', 'TA', 'TB', 'TC', 'TD', 'TE', 'TF', 'TG', 'TH', 'TI', 'TK', 'TL', 'TM', 'TN', 'TO', 'TP', 'TQ', 'TR', 'TS', 'TT', 'TV', 'TX', 'TY', 'TZ', 'VA', 'VB', 'VC', 'VD', 'VE', 'VF', 'VG', 'VH', 'VI', 'VK', 'VL', 'VM', 'VN', 'VO', 'VP', 'VQ', 'VR', 'VS', 'VT', 'VV', 'VX', 'VY', 'VZ', 'XA', 'XB', 'XC', 'XD', 'XE', 'XF', 'XG', 'XH', 'XI', 'XK', 'XL', 'XM', 'XN', 'XO', 'XP', 'XQ', 'XR', 'XS', 'XT', 'XV', 'XX', 'XY', 'XZ', 'YA', 'YB', 'YC', 'YD', 'YE', 'YF', 'YG', 'YH', 'YI', 'YK', 'YL', 'YM', 'YN', 'YO', 'YP', 'YQ', 'YR', 'YS', 'YT', 'YV', 'YX', 'YY', 'YZ', 'ZA', 'ZB', 'ZC', 'ZD', 'ZE', 'ZF', 'ZG', 'ZH', 'ZI', 'ZK', 'ZL', 'ZM', 'ZN', 'ZO', 'ZP', 'ZQ', 'ZR', 'ZS', 'ZT', 'ZV', 'ZX', 'ZY', 'ZZ'],
    showData: 0
  },
  beforeMount: function () {
    this.data = localData;
    var url = window.location.href;
    url = new URL(url);
    var c = url.searchParams.get("id");
    let id = null;
    if (c && c != null) {
      id = this.data.findIndex(function (a) {
        return a['id'] == c;
      });
    }
    if (id != null) {
      this.current = id;
    }
  },
  mounted() {
    var self = this;
    $(".owl-carousel").owlCarousel({
      startPosition: self.current != null ? self.current : 0
    });
    $(".am-next").click(function () {
      $(".owl-carousel").trigger('next.owl.carousel');
    });
    $(".am-prev").click(function () {
      $(".owl-carousel").trigger('prev.owl.carousel');
    });
    var wi = 650;
    var h = 100;
    if (window.screen.width < 1250) {
      wi = 550;
      h = 50;
    }
    var canvas = new fabric.Canvas('canvas', {
      width: wi, height: wi
    });
    var cropped = document.getElementById('canvas2');
    $(cropped).width(wi);
    $(cropped).height(h);
    if (self.data[self.current]['raw_path'] != null) {
      self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['raw_path'], cropped,true);
    } else {
      self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['output_path'], cropped,true);
    }
    $('.canvas-container').on('mousewheel', function (options) {
      var delta = options.originalEvent.wheelDelta;
      if (delta != 0) {
        options.preventDefault();
        var pointer = canvas.getPointer(options, true);
        var point = new fabric.Point(pointer.x, pointer.y);
        if (delta > 0) {
          self.rect.zoomIn(point);
        } else if (delta < 0) {
          self.rect.zoomOut(point);
        }
      }
    });

    this.rect.drawSuccess = function () {
      if (self.data[self.current]['result'] != null) {
        self.data[self.current]['result'] = JSON.parse(self.data[self.current]['result'])
      }
      if (self.data[self.current]['format'] && self.data[self.current]['format'] != null) {
        let list = JSON.parse(self.data[self.current]['format']);
        for (let x of list['results']) {
          self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], null, null, null, x['columns'], x['rows'], x['key'], x['details'], x['position']);
        }
        if (self.data[self.current]['result'] != null) {
          self.extractData = self.data[self.current]['result']['extracted'];
        }
      } else if (self.data[self.current]['result']['extracted'] != null) {
        self.extractData = self.data[self.current]['result']['extracted'];
        let size_w = self.data[self.current]['result']['raw']['size_w'];
        let size_h = self.data[self.current]['result']['raw']['size_h'];
        let list = self.data[self.current]['result']['extracted'];
        let labels = [];
        for (let x in list) {
          for (let y of list[x][0]) {
            labels.push({...y, key: x})
          }
        }
        for (let x of labels) {
          self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], size_w, size_h, x['text'], 1, 1, x['key']);
        }
      } else if (self.data[self.current]['result']) {
        let list = self.data[self.current]['result']['raw']['result'];
        let size_w = self.data[self.current]['result']['raw']['size_w'];
        let size_h = self.data[self.current]['result']['raw']['size_h'];
        self.extractData = self.convertData(list);
        for (let x of list) {
          self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], size_w, size_h, x['text'], 1, 1, x['id']);
        }
      }

      if (self.data[self.current]['result']['suggestion'] != null) {
        // = self.data[self.current]['result']['suggestion'];
        let size_w = self.data[self.current]['result']['raw']['size_w'];
        let size_h = self.data[self.current]['result']['raw']['size_h'];
        let list = self.data[self.current]['result']['suggestion'];
        self.suggestionData = self.convertData(list);
        for (let x of list) {
          self.rect.addSuggest(x["x"] - 5, x["y"] - 5, x["w"] + 10, x["h"] + 10, size_w, size_h, x['text'], 1, 1, x['key'] + '-sg');
        }
      }

      for (let x of self.rect.labels) {
        x.selectable = false;
        x.selection = false;
      }
      for (let x of self.rect.suggestLabels) {
        x.selectable = false;
        x.selection = false;
      }
      self.testData = Object.keys(self.extractData);
    };

    this.rect.callBack = function () {
      let rec = self.rect.canvas.getActiveObject();
      let key = rec['key'];
      if (!key) {
        console.log('');
      } else {
        let rows = $('tr');
        rows.removeClass('active');
        $("tr[data-value=" + key + "]").addClass('active');
        $("tr[data-value=" + key + "]")[0].scrollIntoView({
          behavior: 'smooth',
          block: 'center'
        });
      }
    }
    this.rect.boxCreated = function () {
      let rec = self.rect.canvas.getActiveObject();
      let key = rec['key'];
      if (!key) {
        // console.log('test');
        // let key = 'キー#'+self.rect.labels.length;
        // rec['key'] = key;
        // self.extractData[key] = null;
        self.updateKey(rec)
      }
    }
  },
  methods: {
    convertData(data) {
      var res = {};
      for (let d of data) {
        if (d['key']) {
          res[d['key']] = [[d]]
        } else {
          res[d['id']] = [[d]]
        }
      }
      return res
    },
    findNextColumn(k) {
      return this.listColumn[k]
    },
    findColumn() {
      let k;
      for (let label of this.rect.labels) {
        if (label.position && label.position != '') {
          let id = this.listColumn.findIndex(c => c == label.position);
          if (id > k) {
            k = id
          }
        }
      }
      return k+1
    },
    updateKey(rec) {
      let key = 'キー#' + (this.rect.labels.length + 1);
      rec['key'] = key;
      this.extractData[key] = [[{
        'x': rec.x,
        'y': rec.y,
        'w': rec.w,
        'h': rec.h,
        'text': rec.text,
        'key': rec.key,
        'position': this.findNextColumn(this.findColumn())
      }]];
      this.testData.push(key);
      let rows = $('tr');
      rows.removeClass('active');
      $("tr[data-value=" + key + "]").addClass('active');
      $("tr[data-value=" + key + "]")[0].scrollIntoView({
        behavior: 'smooth',
        block: 'center'
      });
    },
    reDraw() {
      this.showData = this.showData === 0 ? 1 : 0;
      this.rect.clearLabel();
      var self = this;
      if (this.showData === 1) {
        self.extractData = self.convertData(self.data[self.current]['result']['raw']['result']);
        self.suggestionData = self.convertData(self.data[self.current]['result']['raw']['result']);
        let list = self.data[self.current]['result']['raw']['result'];
        let size_w = self.data[self.current]['result']['raw']['size_w'];
        let size_h = self.data[self.current]['result']['raw']['size_h'];
        for (let x of list) {
          self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], size_w, size_h, x['text'], 1, 1, x['id']);
        }
      } else {
        self.extractData = self.data[self.current]['result']['extracted'];
        if (self.data[self.current]['format'] && self.data[self.current]['format'] != null) {
          let list = JSON.parse(self.data[self.current]['format']);
          for (let x of list['results']) {
            self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], null, null, null, x['columns'], x['rows'], x['key'], x['details'], x['position']);
          }
        } else if (self.data[self.current]['result']['extracted'] != null) {
          let list = self.data[self.current]['result']['extracted'];
          let labels = [];
          for (let x in list) {
            for (let y of list[x][0]) {
              labels.push({...y, key: x})
            }
          }
          for (let x of labels) {
            self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], null, null, x['text'], 1, 1, x['key']);
          }
        }
      }
    },
    selectRect(key, e) {
      let x = null;
      for (let a of this.rect.labels) {
        if (a['key'] == key) {
          x = a;
          break;
        }
      }
      this.rect.selectObj(x);
      $('tr').removeClass('active');
      $(e.target).parent('tr').addClass('active');
      // this.rect.canvas.setActiveObject(null);

    },
    selectSuggest(key, e) {
      let x = null;
      for (let a of this.rect.suggestLabels) {
        if (a['key'] == key + '-sg') {
          x = a;
          break;
        }
      }
      this.rect.selectObj(x);
      $('tr').removeClass('active');
      $(e.target).parent('tr').addClass('active');
      // this.rect.canvas.setActiveObject(null);

    },
    showKeyVal: function () {
      if (this.data[this.current]['result']['extracted'] != null) {
        $('#show-table').modal('toggle');
      }
    },
    removeLabel(key, e) {
      let f = this.rect.labels.find(rec => rec['key'] == key);
      this.rect.removeLabel(f);
      $(e.target).parents('tr')[0].remove();
      delete this.data[this.current]['result']['extracted'][key];
    },
    removeSugst(key, e) {
      let f = this.rect.suggestLabels.find(rec => rec['key'] == key);
      this.rect.removeLabel(f);
      $(e.target).parents('tr')[0].remove();
      delete this.data[this.current]['result']['extracted'][key];
    },
    updateStatus() {
      if (this.data[this.current]['view_status'] != true) {
        var xhr = new XMLHttpRequest();
        xhr.onload = function () {
          if (this.status == 200) {
            console.log('success');
          }
        };
        var fd = new FormData();
        fd.append("id", this.data[this.current]['id']);
        xhr.open("POST", "/update_view_status", true);
        xhr.send(fd);
      }
    },
    showStatus(type) {
      if (type == 0) {
        return '実行中'
      } else if (type == 1) {
        return '実行済み'
      } else if (type == 2) {
        return 'エラー'
      } else if (type == 3) {
        return '未実行'
      }
    },
    updateExport() {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        $('body').removeClass('loading');
        let data = JSON.parse(this.response);
        let a = document.createElement("a");
        a.style = "display: none";
        document.body.appendChild(a);
        a.href = data.path;
        a.download = data.path.split('/').pop();
        a.click();
      };
      $('body').addClass('loading');
      var fd = new FormData();
      fd.append("id", this.data[this.current]['id']);
      xhr.open("POST", "/exportv3", true);
      xhr.send(fd);
    },
    saveData() {
      let data = [];
      let zoom = this.rect.getScale();
      for (let lab of this.rect.labels) {
        let d = {
          'x': Math.round(lab.left / zoom),
          'y': Math.round(lab.top / zoom),
          'w': Math.round(lab.width / zoom),
          'h': Math.round(lab.height / zoom),
          'text': lab.text
        };
        data.push(d);
      }

      this.data[this.current]['result']['raw']['result'] = data;
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        $('body').removeClass('loading');
      };
      $('body').addClass('loading');
      var fd = new FormData();
      fd.append("data", JSON.stringify(this.data[this.current]['result']));
      fd.append("id", this.data[this.current]['id']);
      xhr.open("POST", "/save", true);
      xhr.send(fd);
    },
    prettyDate: function (date) {
      let pad = function (val, len) {
        val = String(val);
        len = len || 2;
        while (val.length < len) val = "0" + val;
        return val;
      };
      let a = new Date(date);
      return a.getFullYear() + "/" + pad(a.getMonth() + 1) + "/" + pad(a.getDate()) + ' ' + pad(a.getHours()) + ':' + pad(a.getMinutes());
    },
    nextImg() {
      if (this.current < this.data.length - 1) {
        this.current += 1;
      }
    },
    prevImg() {
      if (this.current > 0) {
        this.current -= 1;
      }
    },
    selectImg(id) {
      this.current = id;
      window.location.replace('/result?id=' + this.data[this.current].id);
    },
    redirect(url) {
      window.location.replace(url)
    },
    showImg(src) {
      $('#imagemodal').modal('show');
      var self = this;
      var zX = self.zoomLevel;
      $('.imagepreview').attr('src', src);
      $('#imagemodal .modal-dialog').bind('mousewheel', function (e) {
        var dir = 0;
        if (e.originalEvent.wheelDelta > 0) {
          dir += 0.1;
        } else {
          dir -= 0.1;
        }
        self.zoomLevel += dir;
        if (self.zoomLevel < 4 && self.zoomLevel >= 1) {
          $(this).css('transform', 'scale(' + self.zoomLevel + ')');
        } else if (self.zoomLevel >= 4) {
          self.zoomLevel = 4;
        } else {
          self.zoomLevel = 1;
        }
      });
    },
    showSVG() {
      $('#show-svg .modal-body').empty();
      let txt = $('#draw-content').html();
      let wd = $('#draw-content').width();

      $('#show-svg .modal-body').append(txt);
      $('#show-svg').modal('show');
      var self = this;
      $('#show-svg .modal-content').width(wd + 50);
      $('#show-svg').bind('mousewheel', function (e) {
        var dir = 0;
        if (e.originalEvent.wheelDelta > 0) {
          dir += 0.1;
        } else {
          dir -= 0.1;
        }
        self.zoomLevel += dir;
        if (self.zoomLevel < 4.0 && self.zoomLevel >= 1) {
          $(this).css('transform', 'scale(' + self.zoomLevel + ')');
        } else if (self.zoomLevel >= 4.0) {
          self.zoomLevel = 4.0;
        } else {
          self.zoomLevel = 1;
        }
      });
    },
    drawSvg() {
      function text(data, scale) {
        let html = "";
        let pad = 0;
        for (let i in data.result) {
          let t = data.result[i];
          let font_size = t.direction == "vert" ? parseInt(t.w * scale / 1.3) : parseInt(t.h * scale / 1.3);
          if (parseInt(t.y) < parseInt(t.h) && t.direction == "horiz")
            pad = parseInt(t.h - t.y);
          html += '<text x="' + parseInt(parseInt(t.x) * scale) + '" y="' + parseInt(parseInt(t.y + pad) * scale) + '" width="' + parseInt(parseInt(t.w) * scale) + '" height="' + parseInt(parseInt(t.h) * scale) + '" font-size="' + (font_size) + '"' + (t.direction == "vert" ? 'transform="rotate(90 ' + parseInt(parseInt(t.x) * scale) + ', ' + parseInt(parseInt(t.y + pad) * scale) + ')"' : '') + '">' + t.text + '</text>'
        }
        return html;
      }

      $('#draw-content').html('');
      if (this.data[this.current]['result'] != null) {
        let data = this.data[this.current]['result']['raw'];
        let w = $('#draw-content').width();
        let per = w / data.size_w;
        per = per > 1 ? 1 : per;
        let html = '<svg  style="background-color: #ffffff" width="' + w + '" height="' + (parseInt(data.size_h * per)) + '">' +
            text(data, per);
        '</svg>'
        $('#draw-content').append(html);
      }
    }
  }
});