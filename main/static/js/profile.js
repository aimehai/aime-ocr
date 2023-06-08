myObject = new Vue({
  el: '#profile',
  data: {
    data: [],
    username: null,
    company_name: null,
    password: null,
    confirmed_password: null,
    update_pass: false,
    update_infor: false,
    password_error: false,
    username_error: false,
    files: null
  },
  beforeMount: function () {
    // this.data = localData;
  },
  methods: {
    showUpdateInfor() {
      this.update_pass = false;
      this.update_infor = true;
    },
    showUpdatePass() {
      this.update_pass = true;
      this.update_infor = false;
    },
    updatePassword() {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        if (this.status == 200) {
          window.location.reload();
        }
      };
      if (this.password == this.confirmed_password) {
        this.password_error = false;
        var fd = new FormData();
        fd.append("pass", this.password);
        xhr.open("POST", "/update_pass", true);
        xhr.send(fd);
      } else {
        this.password_error = true;
      }
    },
    updateAvatar() {
      $('#avatar').click();
    },
    handleFilesUpload() {
      this.files = this.$refs.files.files[0];
      const validImageTypes = ['image/gif', 'image/jpeg', 'image/png'];
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        if (this.status == 200) {
          window.location.reload();
        }
      };
      if (this.files && this.files != null && validImageTypes.includes(this.files['type'])) {
        var fd = new FormData();
        fd.append("avatar", this.files);
        xhr.open("POST", "/update_avatar", true);
        xhr.send(fd);
      }
    },
    updateInfor() {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        if (this.status == 200) {
          window.location.reload();
        }
      };
      if (this.username.trim().length > 0) {
        this.username_error = false;
        var fd = new FormData();
        fd.append("name", this.username);
        xhr.open("POST", "/update_infor", true);
        xhr.send(fd);
      } else {
        this.username_error = true
      }
    },
    cancelUpdate() {
      this.update_pass = false;
      this.update_infor = false;
    }
  }
});