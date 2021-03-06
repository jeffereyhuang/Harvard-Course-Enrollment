library(tidyverse)
library(readxl)
library(janitor)
library(ggplot2)
library(ggthemes)
library(ggrepel)
library(fivethirtyeight)


# file download process — it was difficult to read_xlsx directly from the url, so the easiest way for me to download was by storing it in local directory and reading from there, and then deleting. clean_nanmes() helped with standardizing the naming of the columns

download.file("https://registrar.fas.harvard.edu/files/fas-registrar/files/class_enrollment_summary_by_term_3.22.19.xlsx", "spring_19.xlsx")

spring_19 <- read_xlsx("spring_19.xlsx", skip = 3) %>% 
  clean_names()

fs:::file_delete("spring_19.xlsx")

download.file("http://registrar.fas.harvard.edu/files/fas-registrar/files/class_enrollment_summary_by_term_2017_03_07_final_0.xlsx", "spring_17.xlsx")

spring_17 <- read_xlsx("spring_17.xlsx", skip = 3) %>% 
  clean_names()

fs:::file_delete("spring_17.xlsx")


# filters for undergrad majority classes with more than 3 undergrads in the course, there are sometimes multiple listing for the same course in different sections, so only keep distinct entries. if coming back to this data in the future, I would want to look at how these trends correlate with concentration numbers, to track whether these courses are occuring because changing interests at Harvard overall, or simply courese that everyone wants to take once or twice.

full_courses <- bind_rows(spring_17, spring_19, .id="year") %>%
  drop_na(course_department) %>% 
  distinct(course_id, year, .keep_all = TRUE) %>% 
  mutate(ugrad_ratio = u_grad / total) %>% 
  filter(u_grad > 3) 

# grabs the five departments with the highest difference between 2019 and 2017 total enrollment in undergrad courses. created a column to easily sort and select entries

top_dept <- full_courses %>% 
  select(course_department, u_grad, year) %>%
  group_by(course_department, year) %>% 
  summarize(dept_totals = sum(u_grad)) %>% 
  spread(key=year, value=dept_totals) %>% 
  ungroup() %>% 
  mutate(increase = `2` - `1`) %>% 
  arrange(desc(increase)) %>% 
  slice(1:5)

# select only courses from these departments, and also create a column to display the differences between 2019 and 2017 to easily select entries

course_change <- full_courses %>% 
  filter(course_department %in% top_dept$course_department) %>% 
  select(course_title, course_department, course_id, u_grad, year) %>% 
  group_by(course_id,year) %>% 
  spread(key=year, value=u_grad) %>% 
  ungroup() %>% 
  mutate(increase = `2`-`1`) %>% 
  arrange(desc(increase))

# select the top courses to select from the overall list for coloring purposes

top_5 <- course_change %>% 
  slice(1:5)

# create a T-F variable to then filter by for dislpay purposes

course_plot <- course_change %>% 
  mutate(top = ifelse(course_id %in% top_5$course_id, TRUE, FALSE)) %>% 
  gather("year", "enrollment", `1`:`2`) 


# plot data with first the gray subset of data, then the color subset of data. geom_text_repel labels the colored subset of data for comparison purposes

ggplot(data = subset(course_plot, top == FALSE),
       mapping = aes(x = year, y = enrollment)) +
  geom_point(alpha = 0.15, color = "gray") +
  
  geom_point(data = subset(course_plot, top == TRUE),
             mapping = aes(x = year, y = enrollment, color = course_department)) +
  geom_text_repel(data = subset(course_plot,
                                top == TRUE),
                  mapping = aes(x = year,
                                y = enrollment,
                                label = course_title), size = 2) +
  
  # theme adjustment 
  
  scale_color_fivethirtyeight() +
  theme_fivethirtyeight() +
  theme(legend.title=element_blank(), 
        legend.position="top") + 
  
  # labels for the different elements, overriding default no axis label settings
  
  labs(
    title="Growing Enrollment of the Highest Growing Classes ",
    subtitle="Five Highest Growing Departments from Spring 2017-2019", 
    caption="Source: Harvard Registrar"
  ) +
  scale_x_discrete(labels=c("Spring 2017", "Spring 2019")) +
  theme(axis.title = element_text()) + 
  xlab("Semester") +
  ylab("Enrollment")



