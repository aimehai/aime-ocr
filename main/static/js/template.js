myObject = new Vue({
  el: '#template',
  data: {
    data: [],
    listFilter: [],
    selectedList: [],
    formats: [],
    allSelected: false,
    pageNo: 1,
    pageSize: 10,
    pageCount: 0,
    templateName: null,
    templateId: null,
    cate_name: null
  },
  beforeMount: function () {
    this.data = localData.reverse();
    this.initData();
  },
  mounted() {
  },
  methods: {
    delTemplate: function () {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        if (this.status == 200) {
          window.location.reload();
        }
      };
      $('body').addClass('loading');
      var fd = new FormData();
      fd.append("id", this.selectedList.join(','));
      xhr.open("POST", "/delete_template", true);
      xhr.send(fd);
    },
    create: function () {
      if (this.templateName != null && this.templateName.trim() != '') {
        this.templateName = this.templateName.trim();
        var xhr = new XMLHttpRequest();
        xhr.onload = function () {
          $('body').removeClass('loading');
          $('#create-template').modal('toggle');
          if (this.status == 200) {
            let data = JSON.parse(this.response);
            window.location.replace('/update_template/' + data['id']);
          } else {
            $('#notify').modal('toggle')
          }
        };
        $('body').addClass('loading');
        var fd = new FormData();
        fd.append("name", this.templateName);
        xhr.open("POST", "/create_template", true);
        xhr.send(fd);
      }
    },
    initData: function () {
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.pageCount = Math.ceil(this.data.length / this.pageSize);
      this.listFilter = this.queryFromVirtualDB(startRow, endRow);
    },
    queryFromVirtualDB: function (startRow, endRow) {
      var result = [];
      for (var i = startRow - 1; i < endRow; i++) {
        if (i < this.data.length) {
          result.push(this.data[i]);
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
    selectAll() {
      this.selectedList = [];

      if (this.allSelected) {
        for (let i in this.listFilter) {
          this.selectedList.push(this.listFilter[i].id);
        }
      }
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
    deleteTemplate(id) {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        if (this.status == 200) {
          window.location.reload();
        }
      };
      $('body').addClass('loading');
      var fd = new FormData();
      fd.append("id", id);
      xhr.open("POST", "/delete_template", true);
      xhr.send(fd);
    },
    duplicate(id) {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        if (this.status == 200) {
          window.location.reload();
        }
      };
      $('body').addClass('loading');
      var fd = new FormData();
      fd.append("id", id);
      xhr.open("POST", "/duplicate_template", true);
      xhr.send(fd);
    },
    createTeamplate() {
      $("#create-template").modal('toggle');
    },
    select() {
      this.allSelected = false;
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
    },
    rename: function (id, name) {
      $("#edit-template").modal('toggle');
      this.templateName = name;
      this.templateId = id;
    },
    renameTemp() {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        if (this.status == 200) {
          window.location.reload();
        }
      };
      $('body').addClass('loading');
      var fd = new FormData();
      fd.append("id", this.templateId);
      fd.append("name", this.templateName);
      xhr.open("POST", "/rename_template", true);
      xhr.send(fd);
    },
  }
});