myObject = new Vue({
  el: '#history',
  data: {
    data: [],
    listFilter: [],
    selectedList: [],
    formats: [],
    allSelected: false,
    pageNo: 1,
    pageSize: 10,
    size: 10,
    pageCount: 0,
    socket: null,
    category: [],
    listCategories: [],
    cate_name: null,
    dateFrom: null,
    dateTo: null,
    showPage: []
  },
  beforeMount: function () {
    this.data = localData.data.reverse();
    this.formats = localData.format;
    this.initData();
    this.listCategories = [...new Set(this.data.map(item => item['type']))].filter(a => a != null);
  },
  mounted() {
    var self = this;
    this.socket = io.connect('/start_processing');

    this.socket.on('connected', function (msg) {
      console.log('After connect', msg);
    });

    this.socket.on('update value', function (msg) {
      $('body').removeClass('loading');
      self.updateValue(msg['data']);
    });
  },
  methods: {
    updateValue: function (msg) {
      for (let i in this.listFilter) {
        for (let y in msg) {
          if (this.listFilter[i].id == msg[y].id) {
            this.listFilter[i].status = msg[y].status;
            this.listFilter[i].result = msg[y].result;
            break;
          }
        }
      }
    },
    dateFilter() {
      var self = this;
      let data = null;
      let dateStart = self.dateFrom != null ? new Date(self.dateFrom) : null;
      let dateEnd = self.dateTo != null ? new Date(self.dateTo + ' 23:59') : null;

      if (dateStart == null && dateEnd != null) {
        data = this.data.filter(function (history) {
          return (new Date(history.created_at) <= dateEnd);
        });
      } else if (dateStart != null && dateEnd == null) {
        data = this.data.filter(function (history) {
          return (new Date(history.created_at) >= dateStart);
        });
      } else if (dateStart != null && this.dateFrom != null) {
        data = this.data.filter(function (history) {
          return (new Date(history.created_at) >= dateStart && new Date(history.created_at) <= dateEnd);
        });
      }
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.listFilter = this.queryFromVirtualDB(data, startRow, endRow);
    },
    categoryFilter() {
      var self = this;
      let data = this.data.filter(function (history) {
        if (self.category.length == 0) {
          return true
        }
        if (!history.type || history.type == null) {
          return false
        }
        return (self.category.indexOf(history.type.toLowerCase()) > -1);
      });
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.listFilter = this.queryFromVirtualDB(data, startRow, endRow);
    },
    cateSelectAll() {
      this.category = [];
      let data = this.data;
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.listFilter = this.queryFromVirtualDB(data, startRow, endRow);
    },
    searchName() {
      var self = this;
      let data = this.data.filter(function (history) {
        if (self.cate_name.length == 0) {
          return true
        }
        return (history.name.toLowerCase().indexOf(self.cate_name.toLowerCase()) > -1);
      });
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.listFilter = this.queryFromVirtualDB(data, startRow, endRow);
    },
    initData: function () {
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.pageCount = Math.ceil(this.data.length / this.pageSize);
      this.listFilter = this.queryFromVirtualDB(this.data, startRow, endRow);
      this.showPage = [];
      if (this.pageCount < 6) {
        for (let i = this.pageNo; i <= this.pageCount; i+= 1 ) {
          this.showPage.push(i);
        }
      } else {
        if (this.pageNo + 3 > this.pageCount) {
          for (let i = this.pageCount - 5; i <= this.pageCount; i+= 1 ) {
            this.showPage.push(i);
          }
        } else if (this.pageNo - 3 <= 0) {
          for (let i = 1; i <= 6; i+= 1 ) {
            this.showPage.push(i);
          }
        } else {
          for (let i = this.pageNo - 3; i <= this.pageNo + 2; i+= 1) {
            this.showPage.push(i);
          }
        }
      }
    },
    queryFromVirtualDB: function (data, startRow, endRow) {
      var result = [];
      for (var i = startRow - 1; i < endRow; i++) {
        if (i < data.length) {
          result.push(data[i]);
        }
      }
      return result;
    },
    page: function (pageNo) {
      this.pageNo = pageNo;
      this.initData();
    },
    first: function () {
      this.pageNo = 1;
      this.initData();
    },
    last: function () {
      this.pageNo = this.pageCount;
      this.initData();
    },
    prev: function () {
      if (this.pageNo > 1) {
        this.pageNo -= 1;
        this.initData();
      }
    },
    next: function () {
      if (this.pageNo < this.pageCount) {
        this.pageNo += 1;
        this.initData();
      }
    },
    changePagesize: function () {
      if (this.size == -1) {
        this.pageSize = this.data.length
      } else {
        this.pageSize = parseInt(this.size);
      }
      this.pageCount = 0;
      this.pageNo = 1;
      this.initData();
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
      }  else if (type == 4) {
        return '範囲外'
      }
    },
    selectAll() {
      if (this.allSelected) {
        for (let i in this.listFilter) {
          this.selectedList.push(this.listFilter[i].id);
        }
        this.selectedList = [...new Set(this.selectedList)];
      } else {
        this.selectedList = [];
      }
    },
    select() {
      this.allSelected = false;
    },
    deleteResult() {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        if (this.status == 200) {
          window.location.reload();
        }
      };
      if (this.selectedList.length > 0) {
        $('body').addClass('loading');
        var fd = new FormData();
        fd.append("data", this.selectedList);
        xhr.open("POST", "/delete_result", true);
        xhr.send(fd);
      }
    },
    saveBlob(blob, fileName) {
      var a = document.createElement('a');
      a.href = window.URL.createObjectURL(blob);
      a.download = fileName;
      a.dispatchEvent(new MouseEvent('click'));
    },
    checkFormat(type) {
      for (let x of this.formats) {
        if (type == x.name) {
          return true
        }
      }
      return false
    },
    exportData() {
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
      if (this.selectedList.length > 0) {
        $('body').addClass('loading');
        var fd = new FormData();
        fd.append("data", this.selectedList);
        xhr.open("POST", "/export_multiple", true);
        xhr.send(fd);
      }
    },
    prettyDate: function (date) {
      let pad = function (val, len) {
        val = String(val);
        len = len || 2;
        while (val.length < len) val = "0" + val;
        return val;
      };
      let a = new Date(date);
      return a.getFullYear() + "/" + pad(a.getMonth() + 1) + "/" + pad(a.getDate()) + ' ' + pad(a.getHours()) + ':' + pad(a.getMinutes()) + ':' + pad(a.getSeconds());
    },
    getType: function (id) {
      for (let x of this.data) {
        if (x.id == id) {
          return x.type
        }
      }
      return null
    },
    markError(id, error) {
      for (let i in this.listFilter) {
        if (this.listFilter[i].id == id) {
          this.listFilter[i].error = error
        }
      }
    },
    startProcess: function () {
      if (this.selectedList.length > 0) {
        let error = false;
        let data = {};
        for (let x of this.selectedList) {
          data[x] = this.getType(x);
          // if (data[x] == null) {
          //   this.markError(x, true);
          //   error = true;
          // } else {
          //   this.markError(x, false)
          // }
        }
        if (!error) {
          console.log()
          $('body').addClass('loading');
          this.socket.emit('process', {data: data});
        } else {
          $('#alert').modal('toggle');
        }
      }
    }
  }
});