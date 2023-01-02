#!/bin/bash

opensearch_version=$1
if [[ ${opensearch_version} = "" ]] ; then
  echo "no version."
  exit 1
fi

ml_plugin_version=${opensearch_version}.0
base_dir=$(cd $(dirname $0);pwd)
pom_dir=$base_dir/pom
target_dir=$base_dir/target
jarfiles_dir=$target_dir/jarfiles
git_dir="$target_dir/ml-commons-${ml_plugin_version}"
repo_dir=$target_dir/repository
ml_plugin_file="${target_dir}/opensearch-ml-plugin-${ml_plugin_version}.zip"
ml_plugin_url="https://repo1.maven.org/maven2/org/opensearch/plugin/opensearch-ml-plugin/${ml_plugin_version}/opensearch-ml-plugin-${ml_plugin_version}.zip"
git_url="https://github.com/opensearch-project/ml-commons/archive/refs/tags/${ml_plugin_version}.zip"
git_file="${target_dir}/ml-commons-${ml_plugin_version}.zip"

mkdir -p "${target_dir}"
if [[ ! -f ${ml_plugin_file} ]] ; then
  echo "Downloading from ${ml_plugin_url}"
  curl -s -o ${ml_plugin_file} ${ml_plugin_url}
fi

rm -rf "${jarfiles_dir}"
mkdir "${jarfiles_dir}"
cd "${jarfiles_dir}"
echo "Unzipping ${ml_plugin_file}"
unzip "${ml_plugin_file}" > /dev/null

if [[ ! -f ${git_file} ]] ; then
  echo "Downloading from ${git_url}"
  curl -s -L -o ${git_file} ${git_url}
fi

cd ${target_dir}
rm -rf "${git_dir}"
echo "Unzipping ${git_file}"
unzip "${git_file}" > /dev/null

common_utils_version=$(ls ${jarfiles_dir}/common-utils-*.jar | sed -e "s/.*common-utils-//" -e "s/.jar$//" )
jackson_version=$(ls ${jarfiles_dir}/jackson-databind-*.jar | sed -e "s/.*jackson-databind-//" -e "s/.jar$//" )

cd "${target_dir}"

create_module() {
  module_name=$1
  src_name=$2
  echo "Creating ${module_name}"
  pom_file=${target_dir}/${module_name}-${ml_plugin_version}.pom
  jar_file=${jarfiles_dir}/${module_name}-${ml_plugin_version}.jar
  sed -e "s/__OPENSEARCH_VERSION__/${opensearch_version}/" \
      -e "s/__ML_VERSION__/${ml_plugin_version}/" \
      -e "s/__COMMON_UTILS_VERSION__/${common_utils_version}/" \
      -e "s/__JACKSON_VERSION__/${jackson_version}/" \
    ${pom_dir}/${module_name}.pom > ${pom_file}

  src_file=${target_dir}/${module_name}-${ml_plugin_version}-sources.jar
  javadoc_file=${target_dir}/${module_name}-${ml_plugin_version}-javadoc.jar
  cd ${git_dir}/${src_name}
  mkdir -p src/main/javadoc
  javadoc -locale en -d src/main/javadoc -sourcepath src/main/java -subpackages org
  jar cvf ${javadoc_file} -C src/main/javadoc/ . > /dev/null
  cd src/main/java
  jar cvf ${src_file} * > /dev/null

  mvn deploy:deploy-file -Dgpg.skip=false -Durl=file:${repo_dir} -Dfile=${jar_file} -DpomFile=${pom_file}
  mvn deploy:deploy-file -Dgpg.skip=false -Durl=file:${repo_dir} -Dfile=${src_file} -DpomFile=${pom_file} -Dclassifier=sources
  mvn deploy:deploy-file -Dgpg.skip=false -Durl=file:${repo_dir} -Dfile=${javadoc_file} -DpomFile=${pom_file} -Dclassifier=javadoc
}

mkdir -p ${repo_dir}

create_module opensearch-ml plugin
create_module opensearch-ml-common common
create_module opensearch-ml-algorithms ml-algorithms
