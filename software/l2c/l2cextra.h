  void l2c_mtrr_show(struct l2cregs *l2c);
  void l2c_scrub_show(struct l2cregs *l2c);
  void l2c_error_show(struct l2cregs *l2c);
  void l2c_diag_show_data_line(unsigned int diagd_base, int way, int index, int linesize);
  void l2c_diag_show_tag(unsigned int diagt_base, int index, int linesize, int setsize, int header);

